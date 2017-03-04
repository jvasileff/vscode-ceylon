import ceylon.collection {
    MutableMap,
    MutableSet
}
import ceylon.file {
    Directory,
    Path,
    parsePath,
    parseURI
}
import ceylon.interop.java {
    createJavaStringArray,
    synchronize,
    JavaList
}

import com.redhat.ceylon.common {
    Backend
}
import com.redhat.ceylon.common.config {
    CeylonConfig
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.model.typechecker.model {
    Module
}
import com.vasileff.ceylon.dart.compiler {
    dartBackend
}
import com.vasileff.ceylon.structures {
    MutableMultimap
}

import java.io {
    JFile=File
}
import java.util.concurrent {
    CompletableFuture
}
import java.util.concurrent.atomic {
    AtomicBoolean
}

import org.eclipse.lsp4j {
    MessageType,
    MessageParams,
    Diagnostic,
    PublishDiagnosticsParams
}
import org.eclipse.lsp4j.services {
    LanguageClient
}

shared interface CeylonLanguageServerContext satisfies ErrorListener {
    shared formal LanguageClient languageClient;

    shared formal Directory? rootDirectory;
    shared formal variable Set<Module> moduleCache;
    shared formal variable JsonObject? settings;

    shared formal AtomicBoolean compilingLevel1;
    shared formal AtomicBoolean compilingLevel2;

    shared formal MutableMap<String, String> documents;
    shared formal MutableSet<String> changedDocumentIds;
    shared formal MutableSet<String> documentIdsWithDiagnostics;

    shared formal MutableMultimap<String, CompletableFuture<[PhasedUnit=]>>
            compiledDocumentIdFutures;

    "A map from module name to PhasedUnits."
    shared formal MutableMap<String, [PhasedUnit*]> phasedUnits;

    "The source directories relative to [[rootDirectory]]. Each directory must be
     normalized (i.e. no '..' segments), must not begin with a '.', and must end in
     a '/'."
    shared formal variable [String*] sourceDirectories;

    "The currently configured backend. Must be dart or js."
    shared Backend backend
        =>  switch (backend = ceylonSettings?.getStringOrNull("backend"))
            case ("dart") dartBackend
            case ("js") Backend.javaScript
            else dartBackend;

    shared formal variable Set<String> level1CompilingChangedDocumentIds;
    shared formal variable Set<String> level2CompilingChangedDocumentIds;

    "Modules that have been compiled by level-1 that might be dependencies of modules
     currently being compiled by level-2 for the first time. The potential dependency
     relationships will not be known until the level-2 compile is complete.

     Level-2 must re-queue any modules just compiled that depend on these modules.

     Level-2 must clear [[level2QueuedRoots]] as soon as it has made sure that all
     possible dependents of [[level2QueuedRoots]]s have been recompiled or added to
     [[level2QueuedModuleNames]].

     Level-1 must continue to populate [[level2QueuedModuleNames]] for known dependencies
     (i.e. for dependents that are already cached) since [[level2QueuedRoots]] is not
     effective for that purpose; it is meant soley for uncached dependents."
    shared formal MutableSet<Module> level2QueuedRoots;
    shared formal MutableSet<String> level2QueuedModuleNames;
    shared formal MutableSet<String> level2RefreshingModuleNames;
    shared formal MutableSet<String> cachedModuleNamesCompiledFromSource;

    shared JsonObject? ceylonSettings
        =>  if (is JsonObject settings = settings)
            then settings.getObjectOrNull("ceylon")
            else null;

    shared Boolean generateOutput
        =>  ceylonSettings?.getBooleanOrNull("generateOutput") else false;

    shared CeylonConfig ceylonConfig {
        value config
            =   CeylonConfig.createFromLocalDir(JFile(rootDirectory?.path?.string));

        // FIXME WIP allow empty?
        value configSettings = ceylonSettings?.getObjectOrNull("config");
        value compilerConfig = configSettings?.getObjectOrNull("compiler");
        value repositoriesConfig = configSettings?.getObjectOrNull("repositories");

        if (exists argument = repositoriesConfig?.getStringOrNull("output"),
                !argument.empty) {
            config.setOption("repositories.output", argument);
        }
        if (exists argument = repositoriesConfig?.getArrayOrNull("lookup"),
                !argument.empty) {
            config.setOptionValues("repositories.lookup",
                createJavaStringArray {
                    for (item in argument)
                    if (is String item) item
                });
        }
        if (exists argument = compilerConfig?.getArrayOrNull("suppresswarning"),
                !argument.empty) {
            config.setOptionValues("compiler.suppresswarning",
                createJavaStringArray {
                    for (warning in argument)
                    if (is String warning) warning
                });
        }
        if (exists argument = compilerConfig?.getArrayOrNull("dartsuppresswarning"),
                !argument.empty) {
            config.setOptionValues("compiler.dartsuppresswarning",
                createJavaStringArray {
                    for (warning in argument)
                    if (is String warning) warning
                });
        }
        return config;
    }

    "Inspect source for most recent list of modules."
    shared
    [Module*] nonDefaultModulesInSources
        =>    modulesFromModuleDescriptors {
                sourceFolders = virtualFilesFolders {
                    sourceDirectories = sourceDirectories;
                    listings = documents;
                };
            };

    "Inspect source for most recent list of modules."
    shared
    [String*] allModuleNamesForBackend
        // TODO maintain a list instead of calculating it each time. Add/remove when
        //      module.ceylon changes are detected. We need to distinguish between
        //      all modules and modules for the backend (modules for other backends
        //      still serve to rule out files for the default module.)
        =>  backendCompatibleModules(nonDefaultModulesInSources, backend)
                .map(Module.nameAsString)
                .follow("default")
                .sequence();

    "Inspect source for most recent list of modules."
    shared
    [String*] allModuleNames
        // TODO maintain a list instead of calculating it each time
        =>  nonDefaultModulesInSources
                .map(Module.nameAsString)
                .follow("default")
                .sequence();

    shared
    Map<String, [<String->String>*]> listingsByModuleName
        =>  groupListingsByModuleName {
                // TODO we should really maintain a list of module names in the context
                moduleNames = allModuleNames;
                sourceDirectories = sourceDirectories;
                listings = documents;
            };

    shared
    String? toDocumentIdString(String | Path uri) {
        // The source directory is included in the documentId. For example,
        // 'source/com/example/file.ceylon', or if there is no root directory,
        // '/path/to/file.ceylon'.
        //
        // Note that on windows, documentIds with absolute paths (if there is
        // no root directory) may start with 'drive:' rather than '/'.

        value path
            =   if (is Path uri)
                    then uri
                else if (uri.startsWith("file:"))
                    then parseURI(uri)
                else
                    null;

        if (!exists path) {
            return null;
        }

        value documentId
            =   if (exists rootDirectory = rootDirectory)
                then path.relativePath(rootDirectory.path)
                        .string.replace(operatingSystem.fileSeparator.string, "/")
                else path.string.replace(operatingSystem.fileSeparator.string, "/");

        return documentId;
    }

    shared
    Boolean inSourceDirectory(String documentId)
        =>  sourceDirectories.any((d) => documentId.startsWith(d));

    shared
    Boolean isSourceFile(String? documentId)
        =>  if (exists documentId)
            then inSourceDirectory(documentId)
            else false;

    shared see(`function toDocumentIdString`)
    String toUri(String documentId)
        =>  if (exists rootDirectory = rootDirectory)
            then rootDirectory.path.childPath(documentId)
                    .absolutePath.normalizedPath.uriString
            else parsePath(documentId).uriString;

    shared
    void showInfo(String text) {
        value messageParams = MessageParams();
        messageParams.message = text;
        messageParams.type = MessageType.info;
        languageClient.showMessage(messageParams);
    }

    shared
    void showError(String text) {
        value messageParams = MessageParams();
        messageParams.message = text;
        messageParams.type = MessageType.error;
        languageClient.showMessage(messageParams);
    }

    shared
    void showWarning(String text) {
        value messageParams = MessageParams();
        messageParams.message = text;
        messageParams.type = MessageType.warning;
        languageClient.showMessage(messageParams);
    }

    shared
    void runAsync(Anything() run) {
        // TODO keep track of these, and shut them down if an exit or shutdown
        //      message is recieved
        value runArgument = run;
        CompletableFuture.runAsync(runnable {
            void run() {
                try {
                    runArgument();
                }
                catch (Throwable t) {
                    onError(t);
                }
            }
        });
    }

    shared
    CompletableFuture<[PhasedUnit=]> unitForDocumentId(String? documentId) {
        if (!exists documentId) {
            return CompletableFuture.completedFuture<[PhasedUnit=]>([]);
        }
        value future = CompletableFuture<[PhasedUnit=]>();
        synchronize(this, () {
            if (!isSourceFile(documentId)) {
                // if the documentId is not a sourceFile, complete the future now with []
                future.complete([]);
            }
            else if (!documentId in changedDocumentIds,
                !documentId in level1CompilingChangedDocumentIds,
                !documentId in level2CompilingChangedDocumentIds,
                exists moduleName
                    =   moduleNameForDocumentId(
                                allModuleNames, sourceDirectories, documentId),
                phasedUnits[moduleName] nonempty) {

                // if the documentId has not changed and is in a module that has been
                // compiled, complete the future with the phased units we have now
                future.complete(emptyOrSingleton(findUnitForDocumentId(documentId)));
            }
            else {
                // otherwise, schedule the future to be complete once the documentId has
                // been compiled
                compiledDocumentIdFutures.put(documentId, future);
            }
        });
        return future;
    }

    "Must be called from within a synchronized block on this context."
    shared
    void completeFuturesFor({String*} documentIds) {
        for (documentId in documentIds) {
            for (future in compiledDocumentIdFutures.removeAll(documentId)) {
                completeFuture(documentId->future);
            }
        }
    }

    shared
    PhasedUnit? findUnitForDocumentId(String documentId)
        =>  if (exists moduleName = moduleNameForDocumentId(
                    allModuleNames, sourceDirectories, documentId))
            then (phasedUnits[moduleName] else []).find((pu)
                    =>  pu.unitFile.path == documentId)
            else null;

    shared
    void completeFuture(
            String->CompletableFuture<[PhasedUnit=]> documentIdAndFuture) {
        value documentId->future = documentIdAndFuture;
        future.complete(emptyOrSingleton(findUnitForDocumentId(documentId)));
    }

    shared
    void synchronizeDiagnostics([<String -> List<Diagnostic>>*] documentIdDiagnostics) {
        for (documentId->forDocument in documentIdDiagnostics) {
            if (!forDocument.empty || documentId in documentIdsWithDiagnostics) {
                value p = PublishDiagnosticsParams();
                p.uri = toUri(documentId);
                p.diagnostics = JavaList<Diagnostic>(forDocument);
                languageClient.publishDiagnostics(p);
                if (forDocument.empty) {
                    documentIdsWithDiagnostics.remove(documentId);
                }
                else {
                    documentIdsWithDiagnostics.add(documentId);
                }
            }
        }
    }
}
