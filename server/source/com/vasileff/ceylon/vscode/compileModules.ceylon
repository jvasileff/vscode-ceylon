import ceylon.buffer.charset {
    utf8
}
import ceylon.interop.java {
    createJavaByteArray
}

import com.redhat.ceylon.compiler.typechecker.analyzer {
    UsageWarning
}
import com.redhat.ceylon.compiler.typechecker.io {
    VirtualFile
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Message
}
import com.redhat.ceylon.model.typechecker.model {
    Module
}
import com.vasileff.ceylon.dart.compiler {
    javaList,
    compileDartSP
}
import com.vasileff.ceylon.structures {
    ArrayListMultimap,
    HashMultimap
}
import com.vasileff.ceylon.vscode.internal {
    newDiagnostic,
    log,
    LSContext,
    modulesFromModuleDescriptors,
    flattenVirtualFiles,
    dartCompatibleModules,
    moduleNameForSourceFile,
    moduleNameForDocumentId
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

"Returns a list of compiled documentIds and all diagnostics."
[[String*], [<String->DiagnosticImpl>*]] compileModules(
        [String*] sourceDirectories,
        {<String -> String>*} listings,
        [String*] changedDocs,
        LSContext context) {

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
    value modules = modulesFromModuleDescriptors(sourceFolders);
    value modulesForBackend = dartCompatibleModules(modules)
            .collect((Module.nameAsString));

    // Proof of Concept Module caching
    //
    // Compile:
    //      - The default module and
    //      - modulesForBackend that are
    //          - not cached, or
    //          - have changed files

    value modulesNotCached
        =>  modulesForBackend.select {
                (moduleName) => context.moduleCache.keys.every {
                    (nameAndVersion) => !nameAndVersion.startsWith(moduleName + "/");
                };
            };

    value modulesWithChangedFiles
        =>  changedDocs
                .map {
                    (documentId) => moduleNameForDocumentId {
                        moduleNames = modulesForBackend;
                        sourceDirectories = context.sourceDirectories;
                        documentId = documentId;
                    };
                }.coalesced.distinct.sequence();

    value modulesToCompile
        =>  ["default", *modulesNotCached.chain(modulesWithChangedFiles)];

    "The module cache to use, which excludes modules we are about to compile."
    value moduleCache
        =   map(context.moduleCache.filterKeys {
                (nameAndVersion) => !modulesToCompile.any {
                    (moduleName) => nameAndVersion.startsWith(moduleName + "/");
                };
            });

    log.debug("changedDocs: ``changedDocs``");
    log.debug("moduleCache.keys: ``moduleCache.keys.sequence()``");
    log.debug("modulesForBackend: ``modulesForBackend``");
    log.debug("modulesNotCached: ``modulesNotCached``");
    log.debug("modulesWithChangedFiles: ``modulesWithChangedFiles``");
    log.debug("modulesToCompile: ``modulesToCompile``");

    for (k->m in moduleCache) {
        // TODO clear the type cache? Disable the cache if we do concurrent builds?
        m.cache.clear();
    }

    value [cuList, status, messages, moduleManager] = compileDartSP {
        moduleFilters = modulesToCompile;
        virtualFiles = sourceFolders;
        moduleCache = moduleCache;
    };

    // if no errors, cache the modules
    // TODO try cache modules that have no errors?
    if (messages.map(Entry.item).every(Message.warning)) {
        context.moduleCache = map {
            for (m in moduleManager.modules.listOfModules)
            (m.nameAsString + "/" + m.version)->m
        };
    }

    // Determine what files we actually compiled so that the caller will know what
    // diagnostics can be cleared. This includes all files in all source directories
    // that are not in excluded modules.

    value allModuleNames
        =   modules.collect(Module.nameAsString);

    value skippedModuleNames
        =   allModuleNames.filter(not(modulesToCompile.contains));

    value compiledDocumentIds
        =   sourceFolders.flatMap {
                (folder) => flattenVirtualFiles(folder).map {
                    (file) => file.path -> file.getRelativePath(folder);
                };
            }.filter {
                (documentId -> sourceFile) => !skippedModuleNames.contains {
                    moduleNameForSourceFile(allModuleNames, sourceFile) else "!";
                };
            }.collect(Entry.key);

    log.debug("compiledDocumentIds = ``compiledDocumentIds``");

    return [
        compiledDocumentIds,
        messages.filter((_ -> m)
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
                })
    ];
}
