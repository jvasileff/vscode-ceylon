import com.redhat.ceylon.cmr.ceylon {
    CeylonUtils
}
import com.redhat.ceylon.common {
    Backend
}
import com.redhat.ceylon.common.config {
    CeylonConfig
}
import com.redhat.ceylon.compiler.typechecker.analyzer {
    UsageWarning
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Message,
    TreeNode=Node
}
import com.redhat.ceylon.model.typechecker.model {
    Module
}
import com.vasileff.ceylon.dart.compiler {
    compileDartSP,
    dartBackend,
    CompilationStatus
}
import com.vasileff.ceylon.vscode.compiler {
    compileJS
}

import org.eclipse.lsp4j {
    DiagnosticSeverity,
    Diagnostic
}

"Returns the compiled modules, a list of the compiled documentIds, and all diagnostics."
shared
[[Module*], [PhasedUnit*], [String*], [<String->Diagnostic>*]] compileModules(
        [String*] sourceDirectories,
        Map<String, [<String -> String>*]> listingsByModuleName,
        {Module*} moduleCache,
        CeylonConfig ceylonConfig,
        Boolean generateOutput,
        {String*} moduleNamesToCompile,
        Backend backend) {

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

    [Anything, CompilationStatus, [<TreeNode->Message>*],
    [Module*], [PhasedUnit*]] result;

    if (backend == dartBackend) {
        result = compileDartSP {
            moduleFilters = moduleNamesToCompile;
            virtualFiles = sourceVirtualFileFolders;
            moduleCache = cacheWithoutModulesToCompile;
            suppressWarning = suppressWarningsFromConfig(ceylonConfig);
            outputRepositoryManager = outputRepositoryManager;
        };
    }
    else if (backend == Backend.javaScript) {
        result = compileJS {
            moduleFilters = moduleNamesToCompile;
            virtualFiles = sourceVirtualFileFolders;
            moduleCache = cacheWithoutModulesToCompile;
            suppressWarning = suppressWarningsFromConfig(ceylonConfig);
            outputRepositoryManager = outputRepositoryManager;
        };
    }
    else {
        throw AssertionError("unsupported backend ``backend``");
    }
    value [_, status, messages, modules, phasedUnits] = result;

    log.debug("compile end: modules=``moduleNamesToCompile``");

    return [
        modules,
        phasedUnits,
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
