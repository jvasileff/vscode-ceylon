import com.redhat.ceylon.compiler.typechecker.context {
    Context,
    PhasedUnits
}
import com.redhat.ceylon.cmr.ceylon {
    CeylonUtils
}
import com.vasileff.ceylon.dart.compiler {
    dartBackend
}
import com.redhat.ceylon.model.typechecker.model {
    Module
}
import ceylon.logging {
    debug
}
import com.redhat.ceylon.common.config {
    CeylonConfig
}
import ceylon.interop.java {
    CeylonIterable,
    javaString,
    JavaList
}
import com.redhat.ceylon.compiler.typechecker.io {
    VirtualFile,
    VFS
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

"Returns the module name in [[moduleNames]] that the [[documentId]] belongs to, or null
 if no non-default module can be found."
shared
String? moduleNameForSourceFile(
        "The module name, that is, '.' separated name components without a version."
        [String*] moduleNames,
        "The documentId without the leading source directory, for example,
         `com/example/run.ceylon`"
        String sourceFile)
    =>  moduleNames.filter(not("default".equals)).find((moduleName)
        =>  let (p = packageForSourceFile(sourceFile))
            p == moduleName || p.startsWith(moduleName + "."));

shared
String? sourceFileForDocumentId([String*] sourceDirectories, String documentId)
    =>  let (sourceDir = sourceDirectories.find((d) => documentId.startsWith(d)))
        if (exists sourceDir)
            then documentId[sourceDir.size...]
            else null;

shared
String? moduleNameForDocumentId
        ([String*] moduleNames, [String*] sourceDirectories, String documentId)
    =>  if (exists sourceFile = sourceFileForDocumentId(sourceDirectories, documentId))
        then moduleNameForSourceFile(moduleNames, sourceFile)
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
        log.debug("processing module descriptor '``file.path``'");
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

    if (log.enabled(debug)) {
        for (m in modules) {
            log.debug("Module dependencies for ``m``: \
                       ``[for (i in m.imports) i.\imodule]``");
        }
    }

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
