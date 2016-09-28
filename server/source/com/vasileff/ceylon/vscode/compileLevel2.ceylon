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
void launchLevel2Compiler(LSContext context) {
    // launch a compile task if one isn't running
    if (context.compilingLevel2.compareAndSet(false, true)) {
        log.debug("launching level-2 compiler");
        context.runAsync(() {
            try {
                while(compileLevel2(context)) {}
            }
            finally {
                context.compilingLevel2.set(false);
            }
        });
    }
}

Boolean compileLevel2(LSContext context) {

    value [moduleNamesToCompile, moduleCache, listingsByModuleName,
            changedDocumentIdsToClear] = synchronize(context, () {

        value currentModuleNamesForBackend
            =   context.allModuleNamesForBackend;

        value listingsByModuleName
            =   context.listingsByModuleName;

        "we're starting a new level-2 compile; one shouldn't already be running"
        assert (context.level2RefreshingModuleNames.empty);

        // Clear any new level2Roots. These are only used to immediately invalidate
        // modules that level-2 has compiled for the first time (with dependencies not
        // previously known.) Here, we're starting a compile, not finishing one.
        context.level2QueuedRoots.clear();

        // Compile:
        //  - modules that aren't cached
        //  - deep dependents of modules compiled by level-1
        //  - modules with module descriptor changes and their deep dependents, but
        //    only if level-1 has queued them (level-2 never queues cached modules since
        //    doing so could interfere with in-progress level-1 compiles).

        // TODO in theory we need to worry about module versions since a module could
        //      potentially import an older version of a module that exists in the
        //      workspace.

        "Modules we have source code for, but are not cached. These are newly added
         modules. Note that (except default maybe) these should already be in
         level2QueuedModuleNames due to module descriptor changes, unless they are
         newer than the last run of level-1."
        value uncachedModuleNames
            =   currentModuleNamesForBackend.select((n)
                =>  !context.moduleCache.map(Module.nameAsString).contains(n));

        "All cached dependents of modules queued for compilation that were compiled
         from source."
        value cachedDependentsModuleNames
            =   context.moduleCache.filter {
                    (m) => deepDependenciesWithinSet {
                        m;
                        // Don't search through external modules for dependencies for the
                        // crazy case in which an external dependency depends on a module
                        // we are compiling from source. This happens when editing
                        // ceylon.collection w/the Dart model loader, since
                        // ceylon.collection is a transitive dependency of
                        // ceylon.language. We really *should* be invalidating these
                        // external modules as well, but cheating here to make editing
                        // ceylon-sdk perform ok.
                        // FIXME level-1 needs this note and logic too.
                        context.cachedModuleNamesCompiledFromSource;
                    }
                    .map(Module.nameAsString)
                    .containsAny(context.level2QueuedModuleNames);
                }
                .map(Module.nameAsString)
                // deepDependenciesWithinSet always returns the first argument 'm', even
                // if not in the set provided as the second argument. So, filter:
                .select(context.cachedModuleNamesCompiledFromSource.contains);

        // Refresh all queued modules and cached dependents of queued modules. This
        // includes modules that we are compiling from source plus those that we are
        // removing or updating due to module descriptor changes.
        context.level2RefreshingModuleNames.addAll(context.level2QueuedModuleNames);
        context.level2RefreshingModuleNames.addAll(uncachedModuleNames);
        context.level2RefreshingModuleNames.addAll(cachedDependentsModuleNames);

        "the modules to actually compile from source"
        value moduleNamesToCompile
            =   set {
                    context.level2RefreshingModuleNames.filter(
                        currentModuleNamesForBackend.contains);
                };

        log.debug(()=>"c2-currentModuleNamesForBackend: ``currentModuleNamesForBackend``");
        log.debug(()=>"c2-level2QueuedModuleNames: ``context.level2QueuedModuleNames``");
        log.debug(()=>"c2-uncachedModuleNames: ``uncachedModuleNames``");
        log.debug(()=>"c2-cachedDependentsModuleNames: ``cachedDependentsModuleNames``");
        log.debug(()=>"c2-level2RefreshingModuleNames: ``context.level2RefreshingModuleNames``");
        log.debug(()=>"c2-moduleNamesToCompile: ``moduleNamesToCompile``");

        // make room for new modules to be queued while we are compiling
        context.level2QueuedModuleNames.clear();

        "Modules with removed module descriptors, or that are no longer compatible with
         the configured backend."
        value removedModuleNames
            =   context.level2RefreshingModuleNames.select(
                    not(moduleNamesToCompile.contains));

        log.debug(()=>"c2-removedModuleNames: ``removedModuleNames``");

        if (!removedModuleNames.empty) {
            // clear diagnostics for all files of removed modules
            for (documentId in expand(listingsByModuleName
                        .getAll(removedModuleNames).coalesced)
                        .map(Entry.key)) {
                value p = PublishDiagnosticsParamsImpl();
                p.uri = context.toUri(documentId);
                p.diagnostics = JavaList<DiagnosticImpl>([]);
                context.publishDiagnostics.accept(p);
            }

            // clear removed modules from the cache
            context.moduleCache
                =   set(context.moduleCache.filter((m)
                        =>  !m.nameAsString in removedModuleNames));

            // clear removed modules from list of modules compiled from source
            context.cachedModuleNamesCompiledFromSource.removeAll(removedModuleNames);

            // clear removed modules from context.level2RefreshingModuleNames; we're done
            // dealing with them
            context.level2RefreshingModuleNames.removeAll(removedModuleNames);

            // clear the documentIds now, before calculating changedDocumentIdsToClear
            // which may be added back if the compile below fails. The documentIds were
            // removing here should not be added back.
            context.changedDocumentIds.removeAll {
                context.changedDocumentIds.select((documentId)
                    =>  if (exists sf = sourceFileForDocumentId {
                            context.sourceDirectories;
                            documentId;
                        })
                        then removedModuleNames.any((m)
                            =>  packageBelongsToModule(packageForSourceFile(sf), m))
                        else false);
            };
        }

        value changedDocumentIdsToClear
            // level2RefreshingModuleNames may contain overlapping module names since it
            // includes all changed, removed, and added modules
            =   context.changedDocumentIds.select((documentId)
                =>  if (exists sf = sourceFileForDocumentId {
                        context.sourceDirectories;
                        documentId;
                    })
                    then context.level2RefreshingModuleNames.any((m)
                        =>  packageBelongsToModule(packageForSourceFile(sf), m))
                    else false);

        context.changedDocumentIds.removeAll(changedDocumentIdsToClear);

        log.debug(()=>"c2-changedDocumentIdsToClear: ``changedDocumentIdsToClear``");
        log.debug(()=>"c2-moduleCache context: \
                       ``sort(context.moduleCache.collect(Module.signature))``");

        "the cleaned cache to use for the compile."
        value moduleCache
            =   set(context.moduleCache.filter((m)
                =>  !m.nameAsString in context.level2RefreshingModuleNames));

        log.debug(()=>"c2-moduleCache to use: \
                       ``sort(moduleCache.collect(Module.signature))``");

        return [
            moduleNamesToCompile,
            moduleCache,
            listingsByModuleName,
            changedDocumentIdsToClear
        ];
    });

    if (moduleNamesToCompile.empty) {
        // if there were any level2RefreshingModuleNames, they've have already been cleared
        return false;
    }

    try {
        value [newModules, phasedUnits, compiledDocumentIds, diagnostics]
            =   compileModules {
                    moduleNamesToCompile = moduleNamesToCompile;
                    generateOutput = context.generateOutput;
                    ceylonConfig = context.ceylonConfig;
                    moduleCache = moduleCache;
                    listingsByModuleName = listingsByModuleName;
                    sourceDirectories = context.sourceDirectories;
                };

        synchronize(context, () {
            // save phasedUnits
            context.phasedUnits.putAll {
                *phasedUnits
                    .group((pu) => pu.\ipackage?.\imodule?.nameAsString else "$")
                    .filterKeys(not("$".equals))
            };

            // add results to the current context.cache

            log.debug(()=>"c2-cache-before-updating: \
                           ``sort(context.moduleCache.collect(Module.signature))``");

            context.moduleCache
                // The order matters. Include modules we compiled and invalidated first,
                // then the current context.moduleCache entries (which may have newly
                // compiled modules from level1) minus compiled and invalidated modules,
                // then the rest of 'newModules', which may include some external
                // dependencies.
                =   set {
                        *expand {
                            newModules
                                .filter((m) => m.nameAsString
                                        in context.level2RefreshingModuleNames),
                            context.moduleCache
                                .filter((m) => !m.nameAsString
                                        in context.level2RefreshingModuleNames),
                            newModules
                                // If packages.empty, probably a native import for an
                                // unsupported backend. But... may something else too?
                                //.filter((m) => !m.packages.empty)
                        }
                    };

            // TODO how exactly should TypeCaches be managed?
            for (m in context.moduleCache) {
                m.cache.clear();
            }

            context.cachedModuleNamesCompiledFromSource
                    .removeAll(context.level2RefreshingModuleNames);

            // Should we include all modules we had source for, and not just the sources
            // for the current backend? Probably not since they don't factor in for
            // dependencies.
            context.cachedModuleNamesCompiledFromSource.addAll(
                    moduleNamesToCompile);

            log.debug(()=>"c2-cache-after-updating: \
                           ``sort(context.moduleCache.collect(Module.signature))``");

            log.debug(()=>"c2-cachedModuleNamesCompiledFromSource: \
                           ``sort(context.cachedModuleNamesCompiledFromSource)``");

            // A module we just compiled may have to go back into the queue if both:
            //
            //  - the module's dependencies were previously unknown (changed or new
            //    module.ceylon), leaving level-1 unable to mark it dirty, and
            //
            //  - level-1 compiled a transitive dependency of the dependent module while
            //    we were compiling the dependent module
            value immediatelyStaleModules
                =   context.moduleCache
                        .filter {
                            (m) => m.nameAsString in moduleNamesToCompile;
                        }
                        .select {
                            (m) => deepDependenciesWithinSet {
                                m;
                                context.cachedModuleNamesCompiledFromSource;
                            }.containsAny(context.level2QueuedRoots);
                        };

            log.debug(()=>"c2-immediatelyStaleModules: \
                           ``immediatelyStaleModules.collect(Module.signature)``");

            // queue them for next time
            context.level2QueuedModuleNames.addAll {
                immediatelyStaleModules.map(Module.nameAsString);
            };

            context.level2QueuedRoots.clear();
            context.level2RefreshingModuleNames.clear();
        });

        // Publish Diagnostics

        // FIXME We have to send diags for *all* files, since we need to clear
        // errors!!! Instead, we need to keep a list of files w/errors, to limit
        // the work here.

        // FIXME do this in the sync block?
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
        // add back the documentIds and module names
        synchronize(context, () {
            context.changedDocumentIds.addAll(changedDocumentIdsToClear);
            context.level2QueuedModuleNames.addAll(context.level2RefreshingModuleNames);
            context.level2RefreshingModuleNames.clear();
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
