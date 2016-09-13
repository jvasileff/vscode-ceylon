import ceylon.buffer.charset {
    utf8
}
import ceylon.interop.java {
    createJavaByteArray,
    JavaList,
    javaString,
    CeylonIterable
}

import com.redhat.ceylon.compiler.typechecker.analyzer {
    UsageWarning
}
import com.redhat.ceylon.compiler.typechecker.io {
    VirtualFile,
    VFS
}
import com.redhat.ceylon.compiler.typechecker.parser {
    RecognitionError
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Message,
    AnalysisMessage
}
import com.vasileff.ceylon.dart.compiler {
    javaList,
    compileDartSP,
    dartBackend
}
import com.vasileff.ceylon.structures {
    ArrayListMultimap,
    HashMultimap,
    Multimap
}
import com.vasileff.ceylon.vscode.internal {
    newDiagnostic,
    log
}

import io.typefox.lsapi {
    DiagnosticSeverity
}
import io.typefox.lsapi.impl {
    DiagnosticImpl
}

import java.io {
    ByteArrayInputStream,
    InputStream
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnits,
    Context,
    PhasedUnit
}
import com.redhat.ceylon.cmr.api {
    RepositoryManagerBuilder
}
import com.redhat.ceylon.cmr.ceylon {
    CeylonUtils
}
import com.redhat.ceylon.model.typechecker.util {
    ModuleManager
}
import com.redhat.ceylon.model.typechecker.model {
    Module
}

[<String->DiagnosticImpl>*] compileModules({<String -> String>*} listings1 = {}) {
    // TODO support source directories other than "source/"!
    value listings = listings1.map((path->text) {
        // remove leading "source/" from listings.
        assert (exists slash = path.firstOccurrence('/'));
        return path[slash+1...]->text;
    });

    "The full path, parent directory, and file."
    function pathParts(String path) {
        value trimmed = path.trim('/'.equals);
        value components = trimmed.split('/'.equals).sequence();

        "nonempty paths will have at least one path segment."
        assert (nonempty components);

        return ["/".join(components.exceptLast),
                "/".join(components),
                components.last];
    }

    "The path, and all parent directories."
    function directoryAndParents(String path)
        =>  let (trimmed = path.trim('/'.equals),
                segments = trimmed.split('/'.equals).sequence())
            { for (i in 1:segments.size) "/".join(segments.take(i)) };

    value files
        =   ArrayListMultimap<String, VirtualFile> {
                *listings.map((listing)
                    =>  let ([d, p, n] = pathParts(listing.key))
                        d -> object satisfies VirtualFile {
                            children = javaList<VirtualFile> {};

                            path = p;

                            name = n;

                            folder = false;

                            \iexists() => true;

                            shared actual
                            String? getRelativePath(VirtualFile ancestor)
                                =>  if (path == ancestor.path)
                                        then ""
                                    else if (ancestor.path == "")
                                        then path
                                    else if (path.startsWith("``ancestor.path``/"))
                                        then path[ancestor.path.size+1...]
                                    else null;

                            inputStream
                                =>  ByteArrayInputStream(createJavaByteArray(
                                        utf8.encode(listing.item)));

                            compareTo(VirtualFile other)
                                =>  switch (path.compare(other.path))
                                    case (smaller) -1
                                    case (larger) 1
                                    case (equal) 0;
                        })
            };

    log.debug(()=>"compiling ``files.size`` files");
    log.trace(()=>"files to compile: ``files``");

    value directories
        =   HashMultimap<String, String> {
                *files.keys.flatMap(directoryAndParents).map((directory)
                    =>  let ([d, p, n] = pathParts(directory))
                        d -> p)
            };

    class DirectoryVirtualFile satisfies VirtualFile {
        shared actual String path;

        shared new (String path) {
            this.path = path.trimLeading('/'.equals);
        }

        name = pathParts(path)[2];

        folder = true;

        \iexists() => true;

        shared actual
        String? getRelativePath(VirtualFile ancestor)
            =>  if (path == ancestor.path)
                    then ""
                else if (ancestor.path == "")
                    then path
                else if (path.startsWith("``ancestor.path``/"))
                    then path[ancestor.path.size+1...]
                else null;

        children
            =   javaList<VirtualFile> {
                    expand {
                        directories.get(path).map(DirectoryVirtualFile),
                        files.get(path)
                    };
                };

        compareTo(VirtualFile other)
            =>  switch (path.compare(other.path))
                case (smaller) -1
                case (larger) 1
                case (equal) 0;

        shared actual
        InputStream inputStream {
            throw AssertionError("Directories don't have input streams.");
        }
    }

    value moduleFilters = ["default", *dartCompatibleModules(DirectoryVirtualFile(""))];
    log.debug("compiling with module filters: ``moduleFilters``");

    value [cuList, status, messages] = compileDartSP {
        moduleFilters = moduleFilters;
        virtualFiles = [DirectoryVirtualFile("")];
    };

    // TODO support source directories other than "source/"!
    return messages
        .filter((_->m)
            =>  if (is UsageWarning m)
                then !m.suppressed
                else true)
        // TODO should there be a limit?
        //.take(500)
        .collect((node->message)
            =>  "source/" + node.unit.fullPath -> newDiagnostic {
                    message = message.message;
                    range = rangeForMessage(message);
                    severity = message.warning
                        then DiagnosticSeverity.warning
                        else DiagnosticSeverity.error;
                });
}

[<VirtualFile->VirtualFile>*] flattenVirtualFiles(VirtualFile folder) {
    assert (folder.folder);

    {VirtualFile*} folderAndDescendentFolders(VirtualFile folder)
        =>  CeylonIterable(folder.children)
                .filter(VirtualFile.folder)
                .flatMap(folderAndDescendentFolders)
                .follow(folder);

    return [ for (f in folderAndDescendentFolders(folder))
             for (file in f.children)
             if (!file.folder) f -> file ];
}

[String*] dartCompatibleModules(VirtualFile rootFolder) {
    value ctx = Context(CeylonUtils.repoManager().buildManager(), VFS());
    value pus = PhasedUnits(ctx);
    value moduleSourceMapper = pus.moduleSourceMapper;

    value moduleDescriptors
        =   flattenVirtualFiles(rootFolder).select((folder->file)
            =>  file.name == "module.ceylon");

    // parse all module.ceylon files
    for (folder->file in moduleDescriptors) {
        log.debug("processing module descriptor '``file.path``'");
        for (part in file.path.split('/'.equals).exceptLast) {
            moduleSourceMapper.push(part);
        }
        moduleSourceMapper.visitModuleFile();
        pus.parseUnit(file, folder);
    }

    // Obtain Modules by visiting the phased units.
    //
    // Note: calling visitRemainingModulePhase() on the PhasedUnits doesn't appear
    // necessary; the native() annotations are already set. So we'll just call
    // visitSrcModulePhase() and be done.
    value modules = CeylonIterable(pus.phasedUnits).map<Module?>((pu)
        =>  pu.visitSrcModulePhase() else null).coalesced;

    // Include all modules that are not explicitly excluded, since parse or other errors
    // may make it impossible to determine compatibility
    function dartSupported(Module m)
        =>  m.nativeBackends.none() || m.nativeBackends.supports(dartBackend);

    value allModules
        =   moduleDescriptors.map(Entry.key)
                .map(VirtualFile.path)
                .map((name) => ".".join(name.split('/'.equals)));

    value excludes
        =   modules.filter(not(dartSupported)).collect(Module.nameAsString);

    return allModules.select(not(excludes.contains));
}
