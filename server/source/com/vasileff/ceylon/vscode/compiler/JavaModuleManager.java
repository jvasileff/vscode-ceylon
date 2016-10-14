package com.vasileff.ceylon.vscode.compiler;

import java.util.Collections;
import java.util.List;

import com.redhat.ceylon.cmr.api.ArtifactContext;
import com.redhat.ceylon.cmr.api.RepositoryManager;
import com.redhat.ceylon.common.Backend;
import com.redhat.ceylon.common.Backends;
import com.redhat.ceylon.common.log.Logger;
import com.redhat.ceylon.common.ModuleSpec;
import com.redhat.ceylon.compiler.java.util.Util;
import com.redhat.ceylon.compiler.typechecker.context.Context;
import com.redhat.ceylon.model.cmr.ArtifactResult;
import com.redhat.ceylon.model.loader.AbstractModelLoader;
import com.redhat.ceylon.model.loader.impl.reflect.model.ReflectionModule;
import com.redhat.ceylon.model.loader.impl.reflect.model.ReflectionModuleManager;
import com.redhat.ceylon.model.loader.mirror.ClassMirror;
import com.redhat.ceylon.model.loader.model.LazyModule;
import com.redhat.ceylon.model.loader.model.LazyPackage;
import com.redhat.ceylon.model.typechecker.model.Module;
import com.redhat.ceylon.model.typechecker.model.Modules;
import com.redhat.ceylon.model.typechecker.model.Package;

public class JavaModuleManager extends ReflectionModuleManager {

    private List<String> modulesSpecs;
    //private CeylonDocTool tool;
    //private RepositoryManager outputRepositoryManager;
    private boolean bootstrapCeylon;

    public JavaModuleManager(Context context,
                 List<String> modules,
                 //RepositoryManager outputRepositoryManager,
                 boolean bootstrapCeylon) {
        super();
        //this.outputRepositoryManager = outputRepositoryManager;
        this.modulesSpecs = modules;
        //this.tool = tool;
        this.bootstrapCeylon = bootstrapCeylon;
    }

    @Override
    public boolean isModuleLoadedFromSource(String moduleName) {
        for(String spec : modulesSpecs){
            if(spec.equals(moduleName))
                return true;
        }
        return false;
    }

    @Override
    protected AbstractModelLoader createModelLoader(Modules modules) {
        return new JavaModelLoader(this, modules, bootstrapCeylon){
            @Override
            protected boolean isLoadedFromSource(String className) {
                //return tool.getCompiledClasses().contains(className);
                // FIXME WIP
                return isModuleLoadedFromSource(className);
            }

            @Override
            public ClassMirror lookupNewClassMirror(Module module, String name) {
                // don't load it from class if we are compiling it
                if (isLoadedFromSource(name)) {
                //if(tool.getCompiledClasses().contains(name)){
                    logVerbose("Not loading "+name+" from class because we are typechecking them");
                    return null;
                }
                return super.lookupNewClassMirror(module, name);
            }
            @Override
            protected void logError(String message) {
                //log.error(message);
            }
            @Override
            protected void logVerbose(String message) {
                //log.debug(message);
            }
            @Override
            protected void logWarning(String message) {
                //log.warning(message);
            }
        };
    }

    @Override
    public Package createPackage(String pkgName, Module module) {
        // never create a lazy package for ceylon.language when we're documenting it
        if((pkgName.equals(AbstractModelLoader.CEYLON_LANGUAGE)
                || pkgName.startsWith(AbstractModelLoader.CEYLON_LANGUAGE+"."))
            && isModuleLoadedFromSource(AbstractModelLoader.CEYLON_LANGUAGE))
            return super.createPackage(pkgName, module);
        final Package pkg = new LazyPackage(getModelLoader());
        List<String> name = pkgName.isEmpty() ? Collections.<String>emptyList() : splitModuleName(pkgName);
        pkg.setName(name);
        if (module != null) {
            module.getPackages().add(pkg);
            pkg.setModule(module);
        }
        return pkg;
    }

    @Override
    protected Module createModule(List<String> moduleName, String version) {
        String name = Util.getName(moduleName);
        // never create a reflection module for ceylon.language when we're documenting it
        Module module;
        if(name.equals(AbstractModelLoader.CEYLON_LANGUAGE)
                && isModuleLoadedFromSource(AbstractModelLoader.CEYLON_LANGUAGE))
            module = new Module();
        else
            module = new ReflectionModule(this);
        module.setName(moduleName);
        module.setVersion(version);
        if(module instanceof ReflectionModule)
            setupIfJDKModule((LazyModule) module);
        return module;
    }

    @Override
    public void modulesVisited() {
        // this is very important!
        try{
            super.modulesVisited();
        }catch(Exception x){
            // this can only throw if we're trying to document the language module and it's missing
            throw new RuntimeException("error.languageModuleSourcesMissing"
                    );
                    //tool.getSourceDirs().toArray());
        }
        //for(Module module : getModules().getListOfModules()){
        //    if(isModuleLoadedFromSource(module.getNameAsString())){
        //        addOutputModuleToClassPath(module);
        //    }
        //}
    }

    //private void addOutputModuleToClassPath(Module module) {
    //    ArtifactContext ctx = new ArtifactContext(null, module.getNameAsString(), module.getVersion(), ArtifactContext.CAR);
    //    ArtifactResult result = outputRepositoryManager.getArtifactResult(ctx);
    //    if(result != null)
    //        getModelLoader().addModuleToClassPath(module, result);
    //}

    @Override
    public Backends getSupportedBackends() {
        // This is most likely not the correct solution but it
        // still works for all current cases and allows generating
        // docs for non-JVM modules at the same time
        //return Backends.JAVA.merged(Backend.JavaScript);
        return Backends.JAVA;
    }
}
