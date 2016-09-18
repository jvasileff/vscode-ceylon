import com.redhat.ceylon.cmr.ceylon {
    CeylonUtils
}
import com.redhat.ceylon.common.config {
    CeylonConfig
}
import com.redhat.ceylon.compiler.typechecker.analyzer {
    UsageWarning
}
import com.redhat.ceylon.model.typechecker.model {
    Module
}
import com.vasileff.ceylon.dart.compiler {
    compileDartSP
}
import com.vasileff.ceylon.vscode.internal {
    virtualFilesFolders,
    newDiagnostic,
    log,
    suppressWarningsFromConfig
}

import io.typefox.lsapi {
    DiagnosticSeverity
}
import io.typefox.lsapi.impl {
    DiagnosticImpl
}

"Returns the compiled modules, a list of the compiled documentIds, and all diagnostics."
shared
[[Module*], [String*], [<String->DiagnosticImpl>*]] compileModules(
        [String*] sourceDirectories,
        Map<String, [<String -> String>*]> listingsByModuleName,
        {Module*} moduleCache,
        CeylonConfig ceylonConfig,
        Boolean generateOutput,
        {String*} moduleNamesToCompile) {

    value listingsToCompile
        =   map(expand(listingsByModuleName.getAll(moduleNamesToCompile).coalesced));

    value sourceVirtualFileFolders
        =   virtualFilesFolders {
                sourceDirectories;
                listingsToCompile;
            };

    value cacheWithoutModulesToCompile
        =   map {
                moduleCache
                    .filter((m) => !m.nameAsString in moduleNamesToCompile)
                    .map((m) => m.signature -> m);
            };

    value outputRepositoryManager
        =   generateOutput then
            CeylonUtils.repoManager().config(ceylonConfig).buildOutputManager();

    log.debug("compile begin: generateOutput=``outputRepositoryManager exists``; \
               modules=``moduleNamesToCompile``");

    value [cuList, status, messages, modules] = compileDartSP {
        moduleFilters = moduleNamesToCompile;
        virtualFiles = sourceVirtualFileFolders;
        moduleCache = cacheWithoutModulesToCompile;
        suppressWarning = suppressWarningsFromConfig(ceylonConfig);
        outputRepositoryManager = outputRepositoryManager;
    };

    log.debug("compile end: modules=``moduleNamesToCompile``");

    return [
        modules,
        listingsToCompile.keys.sequence(),
        messages
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
                    })
    ];
}
