import ceylon.collection {
    MutableMap,
    MutableSet
}
import ceylon.file {
    Directory,
    Path,
    parsePath
}
import ceylon.interop.java {
    createJavaStringArray
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

import io.typefox.lsapi {
    ShowMessageRequestParams,
    MessageParams,
    PublishDiagnosticsParams,
    MessageType
}
import io.typefox.lsapi.impl {
    MessageParamsImpl
}
import io.typefox.lsapi.services.transport.trace {
    MessageTracer
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
import java.util.\ifunction {
    Consumer
}

shared interface LSContext satisfies MessageTracer {
    shared formal Consumer<PublishDiagnosticsParams> publishDiagnostics;
    shared formal Consumer<MessageParams> logMessage;
    shared formal Consumer<MessageParams> showMessage;
    shared formal Consumer<ShowMessageRequestParams> showMessageRequest;

    shared formal Directory? rootDirectory;
    shared formal variable Set<Module> moduleCache;
    shared formal variable JsonObject? settings;

    shared formal AtomicBoolean compilingLevel1;
    shared formal AtomicBoolean compilingLevel2;

    shared formal MutableMap<String, String> documents;
    shared formal MutableSet<String> changedDocumentIds;

    "A map from module name to PhasedUnits."
    shared formal MutableMap<String, [PhasedUnit*]> phasedUnits;

    "The source directories relative to [[rootDirectory]]. Each directory must be
     normalized (i.e. no '..' segments), must not begin with a '.', and must end in
     a '/'."
    shared formal variable [String*] sourceDirectories;

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
    [String*] allModuleNamesForBackend
        // TODO maintain a list instead of calculating it each time. Add/remove when
        //      module.ceylon changes are detected. We need to distinguish between
        //      all modules and modules for the backend (modules for other backends
        //      still serve to rule out files for the default module.)
        =>  dartCompatibleModules {
                modulesFromModuleDescriptors {
                    sourceFolders = virtualFilesFolders {
                        sourceDirectories = sourceDirectories;
                        listings = documents;
                    };
                };
            }.collect(Module.nameAsString);

    "Inspect source for most recent list of modules."
    shared
    [String*] allModuleNames
        // TODO maintain a list instead of calculating it each time
        =>   modulesFromModuleDescriptors {
                sourceFolders = virtualFilesFolders {
                    sourceDirectories = sourceDirectories;
                    listings = documents;
                };
            }.collect(Module.nameAsString);

    shared
    Map<String, [<String->String>*]> listingsByModuleName
        =>  groupListingsByModuleName {
                // TODO we should really maintain a list of module names in the context
                moduleNames = allModuleNames;
                sourceDirectories = sourceDirectories;
                listings = documents;
            };

    shared
    String toDocumentIdString(String | Path uri) {
        // Note that the source directory is included in the documentId. For
        // example, 'source/com/example/file.ceylon', or if there is no root
        // directory, '/path/to/file.ceylon'.
        value path
                =   if (is Path uri)
        then uri
        else if (uri.startsWith("file:///"))
        // we need the right kind of Java nio path
        then parsePath(uri[7...])
        else parsePath(uri);

        return if (exists rootDirectory = rootDirectory)
        then path.relativePath(rootDirectory.path).string
        else path.string;
    }

    shared see(`function toDocumentIdString`)
    String toUri(String documentId)
        =>  if (exists rootDirectory = rootDirectory)
            then "file://" + rootDirectory.path.childPath(documentId)
                                .absolutePath.normalizedPath.string
            else "file://" + documentId;

    shared
    void showInfo(String text) {
        value messageParams = MessageParamsImpl();
        messageParams.message = text;
        messageParams.type = MessageType.info;
        showMessage.accept(messageParams);
    }

    shared
    void showError(String text) {
        value messageParams = MessageParamsImpl();
        messageParams.message = text;
        messageParams.type = MessageType.error;
        showMessage.accept(messageParams);
    }

    shared
    void showWarning(String text) {
        value messageParams = MessageParamsImpl();
        messageParams.message = text;
        messageParams.type = MessageType.warning;
        showMessage.accept(messageParams);
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
                catch (AssertionError | Exception t) {
                    onError(t.message, t);
                }
            }
        });
    }
}