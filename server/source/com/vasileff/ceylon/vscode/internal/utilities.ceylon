import com.redhat.ceylon.compiler.typechecker.context {
    Context,
    PhasedUnits
}
import com.redhat.ceylon.cmr.ceylon {
    CeylonUtils
}
import com.vasileff.ceylon.dart.compiler {
    dartBackend,
    Warning
}
import com.redhat.ceylon.model.typechecker.model {
    Module,
    ModuleImport
}
import ceylon.logging {
    debug
}
import com.redhat.ceylon.common.config {
    CeylonConfig,
    DefaultToolOptions
}
import ceylon.interop.java {
    CeylonIterable,
    javaString,
    JavaList,
    javaClass
}
import com.redhat.ceylon.compiler.typechecker.io {
    VirtualFile,
    VFS
}
import ceylon.collection {
    HashSet
}
import java.util {
    EnumSet
}
import com.redhat.ceylon.common.tool {
    EnumUtil
}
import java.lang {
    Class,
    Enum
}

shared
Boolean eq(Anything a, Anything b)
    =>  if (exists a, exists b)
        then a == b
        else (!a exists) && (!b exists);

"Returns the Ceylon package ('.' separated identifiers) for the given sourceFile ('/'
 separated path components including the filename)."
shared
String packageForSourceFile(String sourceFile)
    =>  ".".join(sourceFile.split('/'.equals).exceptLast);

shared
Boolean packageBelongsToModule(String p, String m)
    =>  p == m || p.startsWith(m + ".");

"Returns the module name in [[moduleNames]] that the [[sourceFile]] belongs to, or null
 if no module can be found and `moduleNames` does not contain `default`."
shared
String? moduleNameForSourceFile(
        "The module name, that is, '.' separated name components without a version."
        {String*} moduleNames,
        "The documentId without the leading source directory, for example,
         `com/example/run.ceylon`"
        String sourceFile)
    =>  moduleNames.find((moduleName)
            =>  let (p = packageForSourceFile(sourceFile))
                moduleName != "default"
                    && (p == moduleName || p.startsWith(moduleName + ".")))
            // if not found, then return "default", if that's an option
            else moduleNames.find("default".equals);

shared
String? sourceFileForDocumentId([String*] sourceDirectories, String documentId)
    =>  let (sourceDir = sourceDirectories.find((d) => documentId.startsWith(d)))
        if (exists sourceDir)
            then documentId[sourceDir.size...]
            else null;

shared
String? moduleNameForDocumentId
        ({String*} moduleNames, [String*] sourceDirectories, String documentId)
    =>  if (exists sourceFile = sourceFileForDocumentId(sourceDirectories, documentId))
        then moduleNameForSourceFile(moduleNames, sourceFile)
        else null;

"Basically, if [[documentId]] is in a source directory and ends in `module.ceylon`,
 the package name."
shared
String? moduleNameForModuleDescriptor([String*] sourceDirectories, String documentId)
    =>  if (documentId.endsWith("/module.ceylon"),
            exists sourceFile = sourceFileForDocumentId(sourceDirectories, documentId))
        then packageForSourceFile(sourceFile)
        else null;

shared
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

shared
[Module*] dartCompatibleModules([Module*] modules)
    =>  modules.select {
            (m) => m.nativeBackends.none() || m.nativeBackends.supports(dartBackend);
        };

"Returns a list of modules for all module descriptors found in [[sourceFolders]].
 For any module descriptors that could not be processed by the type checker, a
 default/empty [[Module]] will be returned."
shared
[Module*] modulesFromModuleDescriptors([VirtualFile*] sourceFolders) {

    "A dummy, empty config CeylonConfig(). We don't need overrides.xml to parse
     module.ceylon, and the list of source folders has been provided."
    value ceylonConfig
        =   CeylonConfig();

    value repositoryManager
        =   CeylonUtils.repoManager().config(ceylonConfig).buildManager();

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
        //log.debug("processing module descriptor '``file.path``'");
        for (part in file.path.split('/'.equals).exceptLast) {
            moduleSourceMapper.push(part);
        }
        moduleSourceMapper.visitModuleFile();
        phasedUnits.parseUnit(file, sourceFolder);
    }

    "Typechecker Modules, obtained by visiting the phased units"
    value modules
        =   CeylonIterable(phasedUnits.phasedUnits).collect<Module?>((pu)
            =>  pu.visitSrcModulePhase() else null).coalesced;

    for (pu in phasedUnits.phasedUnits) {
        // necessary to fill in the module dependencies, which we'll want to use
        pu.visitRemainingModulePhase();
    }

    //if (log.enabled(debug)) {
    //    for (m in modules) {
    //        log.debug("Module dependencies for ``m``: \
    //                   ``[for (i in m.imports) i.\imodule]``");
    //    }
    //}

    "All modules based on the module descriptor files we found."
    value allModules
        =   moduleDescriptors
                .map((sourceFolder->file) => file.getRelativePath(sourceFolder))
                .map((name) => name.split('/'.equals).exceptLast)
                .distinct;

    return
    allModules.collect((moduleNameParts)
        =>  phasedUnits.moduleManager.getOrCreateModule(
                JavaList(moduleNameParts.collect(javaString)), null));
}

"All modules that are visible from the given module. A module is visible from a
 module if it is:

 - the module
 - a direct import of the module
 - a `shared` direct import of an import of a visible module"
shared
{Module+} visibleModules(Module m)
    =>  let (visited = HashSet<Module> { m })
        {
            m,
            *CeylonIterable(m.imports)
                .map(ModuleImport.\imodule)
                .flatMap((m) => exportedDependencies(m, visited))
                .follow(m)
        };

{Module*} exportedDependencies(Module m, HashSet<Module> visited) {
    visited.add(m);
    return {
        m,
        *CeylonIterable(m.imports)
            .filter(ModuleImport.export)
            .map(ModuleImport.\imodule)
            .filter(not(visited.contains))
            .flatMap((m) => exportedDependencies(m, visited))
    };
}

"Modules that are visible from the given module and modules that are visible to those
 modules, recursively. This differs from [[visibleModules]] in that some returned modules
 may not be visible to the given module, but only through some dependency chain involving
 non-exported (non-shared) dependencies.

 Only modules with names in the given `Set` are considered."
shared
{Module+} deepDependenciesWithinSet(Module m, {String*} withinGroupModuleNames)
    =>  let (visited = HashSet<Module> { m })
        {
            m,
            *CeylonIterable(m.imports)
                .map(ModuleImport.\imodule)
                .flatMap((m) => deepDependencies(m, visited, withinGroupModuleNames))
                .follow(m)
        };

{Module*} deepDependencies(
        Module m,
        HashSet<Module> visited,
        {String*} withinGroupModuleNames) {
    visited.add(m);
    return {
        m,
        *CeylonIterable(m.imports)
            .map(ModuleImport.\imodule)
            .filter((m) => m.nameAsString in withinGroupModuleNames)
            .filter(not(visited.contains))
            .flatMap((m) => deepDependencies(m, visited, withinGroupModuleNames))
    };
}

"Note: if `default` is not in [[moduleNames]], the resultant map may not contain all
 [[listings]]."
shared see (`function modulesFromModuleDescriptors`)
Map<String, [<String->String>*]> groupListingsByModuleName(
        {<String -> String>*} listings,
        [String*] sourceDirectories,
        {String*} moduleNames)
    =>  listings.group {
            (documentId -> _) => moduleNameForDocumentId {
                documentId = documentId;
                sourceDirectories = sourceDirectories;
                moduleNames = moduleNames;
            } else "!";
        }.filterKeys(not("!".equals));

shared
[Warning*] suppressWarningsFromConfig(CeylonConfig config) {
    // compiler.suppresswarning option
    value result = EnumUtil.enumsFromStrings(javaClass<Warning>(),
            DefaultToolOptions.getCompilerSuppressWarnings(config))
            else EnumSet.noneOf(javaClass<Warning>());
    // compiler.dartsuppresswarning option
    result.addAll(enumsFromStrings(javaClass<Warning>(),
            getCompilerDartSuppressWarnings(config)));
    return CeylonIterable(result).sequence();
}

[String*] getCompilerDartSuppressWarnings(CeylonConfig config)
    =>  if (exists warnings
            =   config.getOptionValues("compiler.dartsuppresswarning"))
        then warnings.iterable.coalesced.map(Object.string).sequence()
        else [];

EnumSet<EnumType> enumsFromStrings<EnumType>(
        Class<EnumType> enumClass, [String*] elements)
        given EnumType satisfies Enum<EnumType> {
    value result = EnumSet<EnumType>.noneOf(enumClass);
    value allValues = EnumSet.allOf(enumClass);
    for (element in elements.map(String.trimmed)
                            .map((String s) => s.replace("-", "_"))) {
        for (e in allValues) {
            if (e.name().equalsIgnoringCase(element)) {
                result.add(e);
            }
        }
    }
    return result;
}
