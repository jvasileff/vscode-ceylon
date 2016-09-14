import com.vasileff.ceylon.vscode.internal {
    log,
    consumer,
    setLogPriority
}

import io.typefox.lsapi.services.json {
    MessageJsonHandler,
    StreamMessageReader,
    StreamMessageWriter
}
import io.typefox.lsapi.services.transport.server {
    LanguageServerEndpoint
}

import java.net {
    Socket
}

shared void run()
    =>  runApp(process.arguments);

shared void runIDE() {
    process.write("Enter space separated arguments: ");
    runApp {
        process.readLine()
            ?.split(Character.whitespace)
            ?.sequence() else [];
    };
}

void runApp([String*] arguments) {
    setLogPriority(arguments[1]);

    value port
        =   if (exists port = arguments[0])
            then parseInteger(port)
            else null;

    if (!exists port) {
        log.fatal("error: no port specified");
        throw Exception("no port specified");
    }

    value socket = Socket("localhost", port);
    log.info("connected to parent using socket on port ``port``");

    value handler = MessageJsonHandler();
    value reader = StreamMessageReader(socket.inputStream, handler);
    value writer = StreamMessageWriter(socket.outputStream, handler);
    value ceylonLanguageServer = LanguageServerWrapper(CeylonLanguageServer());
    value endpoint = LanguageServerEndpoint(ceylonLanguageServer);

    endpoint.setMessageTracer(ceylonLanguageServer);

    reader.setOnError(consumer((Throwable t) => log.error(t.string, t)));
    writer.setOnError(consumer((Throwable t) => log.error(t.string, t)));

    log.info("calling endpoint.connect()");
    endpoint.connect(reader, writer);
    log.info("run() finished");
}
