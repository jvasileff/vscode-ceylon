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
void launchLevel1Compiler(CeylonLanguageServerContext context) {
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

Boolean compileLevel1(CeylonLanguageServerContext context) {

    value [moduleNamesToCompile, moduleCache, listingsByModuleName, futuresToComplete]
            =   synchronize(context, () {

        "starting a new level-1 compile; level1CompilingChangedDocumentIds should
         be empty"
        assert (context.level1CompilingChangedDocumentIds.empty);

        value currentModuleNamesForBackend
            =   context.allModuleNamesForBackend;

        // Ignore modules with module descriptor changes. Have level-2 recompile them.
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

        "Modules that (if not new) currently or previously had illegally nested modules,
         and therefore should be recompiled." // lightly tested
        value sourceAdoptingModules
            =   currentModuleNamesForBackend.select((m)
                =>  !m in moduleNamesWithDescriptorChanges // already queued
                    && moduleNamesWithDescriptorChanges.any((p)
                        =>  packageBelongsToModule(p, m)));

        if (!sourceAdoptingModules.empty) {
            log.debug(()=>"c1-sourceAdoptingModules: \
                           ``sourceAdoptingModules``");
            context.level2QueuedModuleNames.addAll(sourceAdoptingModules);
        }

        // TODO we need to recompile the default module if any module descriptors were
        //      added (the default module will lose sources)

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

        // Conveniently, if a module descriptor is removed, it will appear to the
        // moduleNamesWithChangedFiles calculation as a regular source file, and if its
        // sources are now assigned to the default module, the defualt module will be
        // marked as dirty (included in moduleNamesWithChangedFiles), and we'll recompile
        // it.

        value moduleNamesWithChangedFiles
            =   context.changedDocumentIds.map {
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
                    then
                        // it's in a module we're compiling
                        moduleNamesToCompile.any((m)
                            =>  packageBelongsToModule(packageForSourceFile(sf), m))
                        // or it's in the default module, which we always compile if nec.
                        || moduleNamesToCompile.contains("default")
                            && context.allModuleNames.every((m)
                                =>  !packageBelongsToModule(packageForSourceFile(sf), m))
                    else false);

        log.debug(()=>"c1-changedDocumentIdsToClear: ``changedDocumentIdsToClear``");
        log.debug(()=>"c1-moduleCache context: \
                       ``sort(context.moduleCache.collect(Module.signature))``");

        // Note that we must ignore versions when expiring from the cache. Attempting
        // to keep a different version of a module we are compiling in the cache will
        // break the compile since then the typechecker assigns units to modules (see
        // parseUnit() and ModuleSourceMapper), it does so without version info.
        value moduleCache
            =   set(context.moduleCache.filter((m)
                =>  !m.nameAsString in moduleNamesToCompile));

        log.debug(()=>"c1-moduleCache to use: \
                       ``sort(moduleCache.collect(Module.signature))``");

        context.changedDocumentIds.removeAll(changedDocumentIdsToClear);
        context.level1CompilingChangedDocumentIds = set(changedDocumentIdsToClear);

        return [
            moduleNamesToCompile,
            moduleCache,
            listingsByModuleName,
            changedDocumentIdsToClear.flatMap((documentId)
                =>  context.compiledDocumentIdFutures.removeAll(documentId)
                        .map((future) => documentId->future)).sequence()
        ];
    });

    if (moduleNamesToCompile.empty) {
        launchLevel2Compiler(context);
        return false;
    }

    try {
        value [newModules, phasedUnits, compiledDocumentIds, diagnostics]
            // TODO context.ceylonConfig, sourceDirectories, backend should be obtained
            //      inside synchronized block
            =   compileModules {
                    moduleNamesToCompile = moduleNamesToCompile;
                    generateOutput = context.generateOutput;
                    ceylonConfig = context.ceylonConfig;
                    moduleCache = moduleCache;
                    listingsByModuleName = listingsByModuleName;
                    sourceDirectories = context.sourceDirectories;
                    backend = context.backend;
                };

        // save phasedUnits
        context.phasedUnits.putAll {
            *phasedUnits
                .group((pu) => pu.\ipackage?.\imodule?.nameAsString else "$")
                .filterKeys(not("$".equals))
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

            context.level1CompilingChangedDocumentIds = emptySet;

            // Process any completions, hovers, etc. waiting on the compile. This includes
            //
            //  - futures that existed at before the compiler started for documentIds that
            //    had changes at that time, and
            //
            //  - futures that were created during the compile for compiled documentIds
            //    that do not currently have changes (documents with new changes must be
            //    re-compiled before completing the future.)
            futuresToComplete.each(context.completeFuture);
            context.completeFuturesFor {
                compiledDocumentIds.select((documentId)
                    => !documentId in context.changedDocumentIds);
            };
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
    catch (Throwable e) {
        // add back the documentIds
        synchronize(context, () {
            context.changedDocumentIds.addAll(context.level1CompilingChangedDocumentIds);
            context.level1CompilingChangedDocumentIds = emptySet;
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
