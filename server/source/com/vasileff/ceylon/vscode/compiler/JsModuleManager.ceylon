import ceylon.interop.java {
    javaString,
    JavaCollection
}

import com.redhat.ceylon.common {
    Versions
}
import com.redhat.ceylon.compiler.js.loader {
    JsJsModuleManager=JsModuleManager
}
import com.redhat.ceylon.compiler.typechecker.context {
    Context
}
import com.redhat.ceylon.model.typechecker.model {
    Modules,
    Module
}

import java.util {
    Collections,
    Arrays
}

class JsModuleManager(Context context, String encoding,
        Map<String, Module> moduleCache = emptyMap)
        extends JsJsModuleManager(context, encoding) {

    shared actual
    void initCoreModules(variable Modules initialModules) {
        // Basically the same as super(), but with support for the moduleCache

        // preload modules from the cache, if any
        initialModules.listOfModules.addAll(JavaCollection(moduleCache.items));

        // start with the cache + the passed in set of modules (which should be empty???)
        setModules(initialModules);

        if (!modules.languageModule exists) {
            //build empty package
            value emptyPackage = createPackage("", null);

            value ceylonVersion = Versions.ceylonVersionNumber;

            // create language module and add it as a dependency of defaultModule
            // since packages outside a module cannot declare dependencies
            Module languageModule;
            if (exists m = moduleCache["ceylon.language/``ceylonVersion``"]) {
                // we just added it to initialModules, so just wrap up the config
                languageModule = m;
                modules.languageModule = m;
            }
            else {
                value languageName = Arrays.asList(
                        javaString("ceylon"), javaString("language"));
                languageModule = createModule(languageName, ceylonVersion);
                languageModule.languageModule = languageModule;
                languageModule.available = false;
                modules.languageModule = languageModule;
                modules.listOfModules.add(languageModule);
            }

            // build default module (module in which packages belong to when not
            // explicitly under a module)
            value defaultModuleName = Collections.singletonList(
                    javaString(Module.\iDEFAULT_MODULE_NAME));
            value defaultModule = createModule(defaultModuleName, "unversioned");
            defaultModule.available = true;
            bindPackageToModule(emptyPackage, defaultModule);
            modules.defaultModule = defaultModule;
            modules.listOfModules.add(defaultModule);
        }
    }
}
