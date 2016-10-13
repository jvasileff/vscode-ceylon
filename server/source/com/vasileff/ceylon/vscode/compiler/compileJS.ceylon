import ceylon.interop.java {
    CeylonIterable,
    javaClass,
    javaString
}

import com.redhat.ceylon.cmr.api {
    RepositoryManager
}
import com.redhat.ceylon.compiler.typechecker {
    TypeCheckerBuilder
}
import com.redhat.ceylon.compiler.typechecker.analyzer {
    ModuleSourceMapper
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit,
    TypecheckerUnit
}
import com.redhat.ceylon.compiler.typechecker.io {
    VirtualFile
}
import com.redhat.ceylon.compiler.typechecker.tree {
    TreeNode=Node,
    Message
}
import com.redhat.ceylon.compiler.typechecker.util {
    WarningSuppressionVisitor
}
import com.redhat.ceylon.model.typechecker.context {
    TypeCache
}
import com.redhat.ceylon.model.typechecker.model {
    ModuleModel=Module
}
import com.vasileff.ceylon.dart.compiler {
    Warning,
    CompilationStatus,
    javaList
}

import java.io {
    JFile=File
}
import java.lang {
    Runnable,
    NoSuchFieldException
}
import java.lang.reflect {
    Field
}
import java.util {
    EnumSet
}
import com.redhat.ceylon.common {
    Backend
}

shared
[Anything, CompilationStatus, [<TreeNode->Message>*], [ModuleModel*], [PhasedUnit*]]
compileJS(
        virtualFiles = [],
        sourceDirectories = [],
        sourceFiles = [],
        moduleFilters = [],
        repositoryManager = null,
        outputRepositoryManager = null,
        generateSourceArtifact = false,
        suppressWarning = [],
        doWithoutCaching = false,
        moduleCache = emptyMap) {

    {VirtualFile*} virtualFiles;
    {JFile*} sourceFiles; // for typechecker
    {JFile*} sourceDirectories; // for typechecker

    "A list of modules to compile, or the empty list to compile all modules."
    {String*} moduleFilters;

    RepositoryManager? repositoryManager;
    RepositoryManager? outputRepositoryManager;

    Boolean generateSourceArtifact;

    {Warning*} suppressWarning;

    Boolean doWithoutCaching;

    "The immutable module cache to be used for this compile.

        - The cached *must not* contain entries for modules to be compile.
        - If there is an entry for the default module, it will be ignored.

     Keys are of the form `module.name/version`.

     Note: all `Module`s must be `JsonModule`s!"
    Map<String, ModuleModel> moduleCache;

    value builder = TypeCheckerBuilder();

    virtualFiles.each((f) => builder.addSrcDirectory(f));
    sourceDirectories.each((f) => builder.addSrcDirectory(f));
    builder.setSourceFiles(javaList(sourceFiles));
    if (!moduleFilters.empty) {
        builder.setModuleFilters(javaList(moduleFilters.map(javaString)));
    }
    builder.setRepositoryManager(repositoryManager);

    builder.moduleManagerFactory(JSModuleManagerFactory(moduleCache));

    // Typecheck, silently.
    value typeChecker = builder.typeChecker;

    if (doWithoutCaching) {
        TypeCache.doWithoutCaching(object satisfies Runnable {
            run() => typeChecker.process(true);
        });
    }
    else {
        typeChecker.process(true);
    }

    value phasedUnits
        =   CeylonIterable(typeChecker.phasedUnits.phasedUnits).sequence();

    for (phasedUnit in phasedUnits) {
        // workaround memory leak in
        // https://github.com/ceylon/ceylon/pull/6525
        moduleSourceMapperField?.set(phasedUnit.unit, null);
    }

    // suppress warnings
    value suppressedWarnings
        =   EnumSet.noneOf(javaClass<Warning>());

    suppressedWarnings.addAll(javaList(suppressWarning));

    value warningSuppressionVisitor
        =   WarningSuppressionVisitor<Warning>(
                javaClass<Warning>(), suppressedWarnings);

    phasedUnits.map(PhasedUnit.compilationUnit).each((cu)
        =>  cu.visit(warningSuppressionVisitor));

    value errorVisitor
        =   ErrorCollectingVisitor(Backend.javaScript);

    phasedUnits.map(PhasedUnit.compilationUnit).each((cu)
        =>  cu.visit(errorVisitor));

    // if there are dependency errors, report only them
    value dependencyErrors
        =   errorVisitor.positionedMessages
            .filter((pm)
                => pm.message is ModuleSourceMapper.ModuleDependencyAnalysisError)
            .sequence();

    value messages
        =   if (dependencyErrors nonempty)
            then dependencyErrors
            else errorVisitor.positionedMessages;

    return [
        null,
        CompilationStatus.errorTypeChecker,
        messages.collect((m) => m.node->m.message),
// TODO return modules once moduleCache is supported
//            CeylonIterable {
//                typeChecker.phasedUnits.moduleManager.modules.listOfModules;
//            }.sequence(),
        [],
        phasedUnits
    ];
}

Field? moduleSourceMapperField = (() {
    try {
        value field
            =   javaClass<TypecheckerUnit>()
                    .getDeclaredField("moduleSourceMapper");

        field.accessible = true;
        return field;
    }
    catch (NoSuchFieldException e) {
        return null;
    }
})();
