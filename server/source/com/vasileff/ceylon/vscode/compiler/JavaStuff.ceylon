import com.redhat.ceylon.compiler.typechecker.context {
    Context
}
import com.redhat.ceylon.compiler.java.tools {
    CeyloncCompilerDelegate
}
import com.redhat.ceylon.compiler.typechecker.util {
    ModuleManagerFactory
}
import com.redhat.ceylon.ceylondoc {
    CeylonDocModuleManager,
    CeylonDocModuleSourceMapper
}
import com.redhat.ceylon.model.typechecker.model {
    Module
}
import com.redhat.ceylon.model.typechecker.util {
    ModuleManager
}
import com.redhat.ceylon.compiler.typechecker.analyzer {
    ModuleSourceMapper
}
import com.redhat.ceylon.compiler.js.loader {
    JsModuleSourceMapper
}
import com.redhat.ceylon.common {
    ModuleSpec
}
import com.vasileff.ceylon.dart.compiler {
    javaList
}
import ceylon.interop.java {
    javaString
}

shared
class JavaModuleManagerFactory(
        {String*} moduleNamesToCompile,
        "The immutable module cache to be used for all `ModuleSourceMapper`s created
         by this factory.

            - The cached *must not* contain entries for modules to be compile.
            - If there is an entry for the default module, it will be ignored.

         Keys are of the form `module.name/version`."
        Map<String, Module> moduleCache = emptyMap)
        satisfies ModuleManagerFactory {

    shared actual
    ModuleManager createModuleManager(Context context)
        =>  JavaModuleManager(
                context,
                javaList(moduleNamesToCompile.map(javaString)),
                false);

    shared actual
    ModuleSourceMapper createModuleManagerUtil
            (Context context, ModuleManager moduleManager) {
        assert (is JavaModuleManager moduleManager);
        return JavaModuleSourceMapper(context, moduleManager);
    }
}
