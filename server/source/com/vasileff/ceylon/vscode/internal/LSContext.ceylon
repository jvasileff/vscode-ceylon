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

    "The source directories relative to [[rootDirectory]]. Each directory must be
     normalized (i.e. no '..' segments), must not begin with a '.', and must end in
     a '/'."
    shared formal variable [String*] sourceDirectories;
}
