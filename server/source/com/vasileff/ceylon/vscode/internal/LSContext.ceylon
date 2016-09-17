import com.redhat.ceylon.model.typechecker.model {
    Module
}
import ceylon.file {
    Directory
}
import java.util.\ifunction {
    Consumer
}
import io.typefox.lsapi {
    ShowMessageRequestParams,
    MessageParams,
    PublishDiagnosticsParams
}
import java.io {
    JFile=File
}
import com.redhat.ceylon.common.config {
    CeylonConfig
}
import ceylon.interop.java {
    createJavaStringArray
}

shared interface LSContext {
    shared formal Consumer<PublishDiagnosticsParams> publishDiagnostics;
    shared formal Consumer<MessageParams> logMessage;
    shared formal Consumer<MessageParams> showMessage;
    shared formal Consumer<ShowMessageRequestParams> showMessageRequest;

    shared formal Directory? rootDirectory;
    shared formal variable Map<String, Module> moduleCache;
    shared formal variable JsonObject? settings;

    shared JsonObject? ceylonSettings
        =>  if (is JsonObject settings = settings)
            then settings.getObjectOrNull("ceylon")
            else null;

    shared Boolean generateOutput
        =>  ceylonSettings?.getBooleanOrNull("generateOutput") else false;


    shared CeylonConfig ceylonConfig {
        value config
            =   CeylonConfig.createFromLocalDir(JFile(rootDirectory?.path?.string));


        // FIXME WIP allow empty?
        value configSettings = ceylonSettings?.getObjectOrNull("config");
        value compilerConfig = configSettings?.getObjectOrNull("compiler");
        value repositoriesConfig = configSettings?.getObjectOrNull("repositories");

        if (exists argument = repositoriesConfig?.getStringOrNull("output"),
                !argument.empty) {
            config.setOption("repositories.output", argument);
        }
        if (exists argument = repositoriesConfig?.getArrayOrNull("lookup"),
                !argument.empty) {
            config.setOptionValues("repositories.lookup",
                createJavaStringArray {
                    for (item in argument)
                    if (is String item) item
                });
        }
        if (exists argument = compilerConfig?.getArrayOrNull("suppresswarning"),
                !argument.empty) {
            config.setOptionValues("compiler.suppresswarning",
                createJavaStringArray {
                    for (warning in argument)
                    if (is String warning) warning
                });
        }
        if (exists argument = compilerConfig?.getArrayOrNull("dartsuppresswarning"),
                !argument.empty) {
            config.setOptionValues("compiler.dartsuppresswarning",
                createJavaStringArray {
                    for (warning in argument)
                    if (is String warning) warning
                });
        }
        return config;
    }

    "The source directories relative to [[rootDirectory]]. Each directory must be
     normalized (i.e. no '..' segments), must not begin with a '.', and must end in
     a '/'."
    shared formal variable [String*] sourceDirectories;
}
