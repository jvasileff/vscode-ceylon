import ceylon.interop.java {
    JavaList,
    synchronize
}

import com.redhat.ceylon.model.typechecker.model {
    Module
}
import com.vasileff.ceylon.dart.compiler {
    ReportableException
}
import com.vasileff.ceylon.structures {
    ArrayListMultimap
}

import io.typefox.lsapi.impl {
    DiagnosticImpl,
    PublishDiagnosticsParamsImpl
}

shared
void launchLevel1Compiler(LSContext context) {
    // launch a compile task if one isn't running
    if (context.compilingLevel1.compareAndSet(false, true)) {
        log.debug("launching level-1 compiler");
        context.runAsync(() {
            try {
                while (compileLevel1(context)) {}
            }
            finally {
                context.compilingLevel1.set(false);
            }
        });
    }
}

Boolean compileLevel1(LSContext context) {

    value [moduleNamesToCompile, moduleCache, listingsByModuleName,
            changedDocumentIdsToClear] = synchronize(context, () {

        value currentModuleNamesForBackend
            =   context.allModuleNamesForBackend;

        // Ignore modules with module descriptor changes. Level-2 will recompile them.
        // By adding to `level2QueuedModuleNames`, we'll also ignore their dependents,
        // which level-2 will also recompile.
        value moduleNamesWithDescriptorChanges
            =   context.changedDocumentIds.select {
                    (documentId) => documentId.endsWith("/module.ceylon");
                }.map {
                    (documentId) => moduleNameForModuleDescriptor {
                        sourceDirectories = context.sourceDirectories;
                        documentId = documentId;
                    };
                }.coalesced.sequence();

        log.debug(()=>"c1-moduleNamesWithDescriptorChanges: \
                       ``moduleNamesWithDescriptorChanges``");
        context.level2QueuedModuleNames.addAll(moduleNamesWithDescriptorChanges);

        // Preconditions:
        //
        //    - no module will exist in the cache that has visibility to an uncached
        //      module unless it is directly listed in level2QueuedModuleNames or
        //      level2CompilingModuleNames.
        //
        //    - given locked = level2QueuedModuleNames + level2RefreshingModuleNames,
        //      locked will include all cached modules that recursively depend on modules
        //      in locked.
        //
        //      level-2 must not add a module that has just been compiled for the first
        //      time to the moduleCache without also adding it to the queue if
        //      its newly discovered imports allow it to see either a dirty module
        //      (level2QueuedModuleNames) or one that has more recently been compiled by
        //      level-1 (level2QueuedRoots). The first (queued) is implicit.

        value lockedModuleNames
            =   set(context.level2QueuedModuleNames.chain(
                    context.level2RefreshingModuleNames));

        log.debug(()=>"c1-lockedModuleNames: ``lockedModuleNames``");

        "Modules that level-1 can compile without contention"
        value availableModulesForBackend
            =   context.moduleCache
                    .filter((m) => !m.nameAsString in lockedModuleNames)
                    .filter((m) => m.nameAsString in currentModuleNamesForBackend);

        log.debug(()=>"c1-availableModulesForBackend: \
                       ``availableModulesForBackend.collect(Module.signature)``");


        value listingsByModuleName
            =   context.listingsByModuleName;

        value moduleNamesWithChangedFiles
            =>  context.changedDocumentIds.map {
                    (documentId) => moduleNameForDocumentId {
                        moduleNames = listingsByModuleName.keys;
                        sourceDirectories = context.sourceDirectories;
                        documentId = documentId;
                    };
                }.coalesced.distinct.sequence();

        log.debug(()=>"c1-changedDocumentIds: ``context.changedDocumentIds``");
        log.debug(()=>"c1-moduleNamesWithChangedFiles: ``moduleNamesWithChangedFiles``");

        value changedModulesToCompile
            =   availableModulesForBackend.select((m)
                    =>  m.nameAsString in moduleNamesWithChangedFiles);

        log.debug(()=>"c1-changedModulesToCompile: " +
                  changedModulesToCompile.collect(Module.signature).string);

        "Module names for modules we can't compile that have changed files and that are
         not queued for processing by level-2. Level-2 will clear changedDocumentIds for
         those. (If queued for level-2, it would be for a module descriptor change.)"
        value changedModuleNamesNotForBackend
            =   moduleNamesWithChangedFiles.select((moduleName)
                =>  !moduleName in currentModuleNamesForBackend
                    && !moduleName in context.level2QueuedModuleNames
                    && !moduleName in context.level2RefreshingModuleNames);

        log.debug(()=>"c1-changedModuleNamesNotForBackend: " +
                  changedModuleNamesNotForBackend.string);

        // clear changed documentIds for modules we don't care about
        context.changedDocumentIds.removeAll {
            context.changedDocumentIds.select((documentId)
                =>  if (exists sf = sourceFileForDocumentId {
                        context.sourceDirectories;
                        documentId;
                    })
                    then changedModuleNamesNotForBackend.any((m)
                        =>  packageBelongsToModule(packageForSourceFile(sf), m))
                    else false);
        };

        "all cached modules that may not be changed, but do have visibility to a changed
         module."
        value provisionallyDirtyModules
            =   availableModulesForBackend.select((m)
                =>  deepDependenciesWithinSet(
                            m, context.cachedModuleNamesCompiledFromSource)
                    .containsAny(changedModulesToCompile));

        log.debug(()=>"c1-provisionallyDirtyModules: \
                       ``provisionallyDirtyModules.collect(Module.signature)``");

        "Unchanged modules that we should compile since a) they can see changed modules
         and b) have changed modules that can see them. These modules may have errors now
         due to api changes in their dependencies, and further, if not compiled now, would
         leave their changed dependents with stale references if the dependents weren't
         re-compiled when these intervening modules would otherwise be eventually
         compiled. Just compile them."
        value interveningModules
            =   provisionallyDirtyModules.select((m)
                =>  changedModulesToCompile.any((changed)
                    =>  deepDependenciesWithinSet(
                                changed, context.cachedModuleNamesCompiledFromSource)
                        .contains(m)));

        log.debug(()=>"c1-interveningModules: \
                       ``interveningModules.collect(Module.signature)``");

        value moduleNamesToCompile
            // interveningModules contains all changedModulesToCompile
            =   set(interveningModules.map(Module.nameAsString));

        log.debug(()=>"c1-moduleNamesToCompile: ``moduleNamesToCompile``");

        value changedDocumentIdsToClear
            =   context.changedDocumentIds.select((documentId)
                =>  if (exists sf = sourceFileForDocumentId {
                        context.sourceDirectories;
                        documentId;
                    })
                    then moduleNamesToCompile.any((m)
                        =>  packageBelongsToModule(packageForSourceFile(sf), m))
                    else false);

        log.debug(()=>"c1-changedDocumentIdsToClear: ``changedDocumentIdsToClear``");
        log.debug(()=>"c1-moduleCache context: \
                       ``sort(context.moduleCache.collect(Module.signature))``");

        value moduleCache
            =   set(context.moduleCache.filter((m)
                =>  !m.nameAsString in moduleNamesToCompile));

        log.debug(()=>"c1-moduleCache to use: \
                       ``sort(moduleCache.collect(Module.signature))``");

        context.changedDocumentIds.removeAll(changedDocumentIdsToClear);

        return [
            moduleNamesToCompile,
            moduleCache,
            listingsByModuleName,
            changedDocumentIdsToClear
        ];
    });

    if (moduleNamesToCompile.empty) {
        launchLevel2Compiler(context);
        return false;
    }

    try {
        value [newModules, compiledDocumentIds, diagnostics]
            =   compileModules {
                    moduleNamesToCompile = moduleNamesToCompile;
                    generateOutput = context.generateOutput;
                    // TODO do we need to manage lifecycle of ceylonConfg and use one
                    //      obtained within context lock?
                    ceylonConfig = context.ceylonConfig;
                    moduleCache = moduleCache;
                    listingsByModuleName = listingsByModuleName;
                    sourceDirectories = context.sourceDirectories;
                };

        synchronize(context, () {
            // add results to the current context.cache

            log.debug(()=>"c1-cache-before-updating: \
                           ``sort(context.moduleCache.collect(Module.signature))``");

            context.moduleCache
                =   set {
                        // The order matters: modules listed first are selected in case
                        // of conflict
                        *expand {
                            newModules
                                .filter((m) => m.nameAsString in moduleNamesToCompile),
                            context.moduleCache,
                            newModules
                                // If packages.empty, probably a native import for an
                                // unsupported platform. But... may something else too?
                                //.filter((m) => !m.packages.empty)
                        }
                    };

            // TODO how exactly should TypeCaches be managed?
            for (m in context.moduleCache) {
                m.cache.clear();
            }

            log.debug(()=>"c1-cache-after-updating: \
                           ``sort(context.moduleCache.collect(Module.signature))``");

            log.debug(()=>"c1-cachedModuleNamesCompiledFromSource: \
                            ``sort(context.cachedModuleNamesCompiledFromSource)``");

            // now, fill queue for level-2.
            //  - based on current cache
            //  -

            context.level2QueuedRoots.addAll(newModules.filter((m)
                    => m.nameAsString in moduleNamesToCompile));

            log.debug(()=>"c1-level2QueuedModuleNames before adding: \
                           ``context.level2QueuedModuleNames``");

            // add anything that's cached, deeply depends on a newly compiled module, and
            // we have source for.
            context.level2QueuedModuleNames.addAll(
                context.moduleCache
                    .filter((m) => m.nameAsString in
                            context.cachedModuleNamesCompiledFromSource)
                    .filter((m) => !m.nameAsString in moduleNamesToCompile)
                    .filter {
                        (m) => deepDependenciesWithinSet {
                            m;
                            context.cachedModuleNamesCompiledFromSource;
                        }
                        .map(Module.nameAsString)
                        .containsAny(moduleNamesToCompile);
                    }
                    .map(Module.nameAsString));

            log.debug(()=>"c1-level2QueuedModuleNames after adding: \
                           ``context.level2QueuedModuleNames``");
        });

        launchLevel2Compiler(context);

        // Publish Diagnostics

        // FIXME We have to send diags for *all* files, since we need to clear
        // errors!!! Instead, we need to keep a list of files w/errors, to limit
        // the work here.
        value diagnosticsMap = ArrayListMultimap { *diagnostics };
        for (documentId in compiledDocumentIds) {
            value forDocument = diagnosticsMap[documentId] else [];
            value p = PublishDiagnosticsParamsImpl();
            p.uri = context.toUri(documentId);
            p.diagnostics = JavaList<DiagnosticImpl>(forDocument);
            context.publishDiagnostics.accept(p);
        }
    }
    catch (Exception | AssertionError e) {
        // add back the documentIds
        synchronize(context, () {
            context.changedDocumentIds.addAll(changedDocumentIdsToClear);
        });

        log.error("failed compile");

        value sb = StringBuilder();
        printStackTrace(e, sb.append);

        value exceptionType
            =   if (!e is ReportableException)
                then let (cn = className(e))
                     cn[((cn.lastOccurrence('.')else-1)+1)...] + ": "
                else "";

        context.showError("Compilation failed: ``exceptionType``\
                           ``e.message.replace("\n", "; ")``\
                           \n\n``sb.string``");

        // wrap, so we don't re-report to the user
        throw ReportedException(e);
    }

    return true;
}
