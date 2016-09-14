import ceylon.buffer.charset {
    utf8
}
import ceylon.interop.java {
    createJavaByteArray,
    CeylonIterable
}

import com.redhat.ceylon.cmr.ceylon {
    CeylonUtils
}
import com.redhat.ceylon.common.config {
    CeylonConfig
}
import com.redhat.ceylon.compiler.typechecker.analyzer {
    UsageWarning
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnits,
    Context
}
import com.redhat.ceylon.compiler.typechecker.io {
    VirtualFile,
    VFS
}
import com.redhat.ceylon.model.typechecker.model {
    Module
}
import com.vasileff.ceylon.dart.compiler {
    javaList,
    compileDartSP,
    dartBackend
}
import com.vasileff.ceylon.structures {
    ArrayListMultimap,
    HashMultimap
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

[<String->DiagnosticImpl>*] compileModules(
        [String*] sourceDirectories, {<String -> String>*} listings) {

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

    value dirsWithoutTrailingSlash = sourceDirectories.map((d) => d[0:d.size-1]);
    value sourceFolders = dirsWithoutTrailingSlash.collect(DirectoryVirtualFile);
    value moduleFilters = ["default", *dartCompatibleModules(sourceFolders)];
    log.debug("compiling with module filters: ``moduleFilters``");

    value [cuList, status, messages] = compileDartSP {
        moduleFilters = moduleFilters;
        virtualFiles = sourceFolders;
    };

    return messages
        .filter((_ -> m)
            =>  if (is UsageWarning m)
                then !m.suppressed
                else true)
        .collect((node->message)
            =>  node.unit.fullPath -> newDiagnostic {
                    message = message.message;
                    range = rangeForMessage(message);
                    severity = message.warning
                        then DiagnosticSeverity.warning
                        else DiagnosticSeverity.error;
                });
}

[VirtualFile*] flattenVirtualFiles(VirtualFile folder) {
    assert (folder.folder);

    {VirtualFile*} folderAndDescendentFolders(VirtualFile folder)
        =>  CeylonIterable(folder.children)
                .filter(VirtualFile.folder)
                .flatMap(folderAndDescendentFolders)
                .follow(folder);

    return [ for (f in folderAndDescendentFolders(folder))
             for (file in f.children)
             if (!file.folder) file ];
}

[String*] dartCompatibleModules([VirtualFile*] sourceFolders) {

    "A dummy, empty config CeylonConfig(). We don't need overrides.xml to parse
     module.ceylon, and the list of source folders has been provided."
    value ceylonConfig
        =   CeylonConfig();

    value repositoryManager
        =   CeylonUtils.repoManager().config(CeylonConfig()).buildManager();

    value context
        =   Context(repositoryManager, VFS());

    value phasedUnits
        =   PhasedUnits(context);

    value moduleSourceMapper
        =   phasedUnits.moduleSourceMapper;

    value moduleDescriptors
        =   sourceFolders.flatMap((sourceFolder)
            =>  flattenVirtualFiles(sourceFolder)
                    .filter((file) => file.name == "module.ceylon")
                    .map((file) => sourceFolder->file));

    // parse all found module.ceylon descriptors
    for (sourceFolder -> file in moduleDescriptors) {
        log.debug("processing module descriptor '``file.path``'");
        for (part in file.path.split('/'.equals).exceptLast) {
            moduleSourceMapper.push(part);
        }
        moduleSourceMapper.visitModuleFile();
        phasedUnits.parseUnit(file, sourceFolder);
    }

    "Typechecker Modules, obtained by visiting the phased units"
    value modules
        =   CeylonIterable(phasedUnits.phasedUnits).map<Module?>((pu)
            =>  pu.visitSrcModulePhase() else null).coalesced;

    function dartSupported(Module m)
        =>  m.nativeBackends.none() || m.nativeBackends.supports(dartBackend);

    "All modules based on the module descriptor files we found."
    value allModules
        =   moduleDescriptors
                .map((sourceFolder->file) => file.getRelativePath(sourceFolder))
                .map((name) => ".".join(name.split('/'.equals).exceptLast));

    "All modules that are not explicitly excluded, since parse or other errors
     may make it impossible to determine compatibility, and when in doubt, include."
    value excludes
        =   modules.filter(not(dartSupported)).collect(Module.nameAsString);

    return allModules.select(not(excludes.contains));
}
