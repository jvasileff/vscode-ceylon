import com.vasileff.ceylon.vscode.internal {
    log,
    consumer,
    setLogPriority
}

import io.typefox.lsapi {
    Message
}
import io.typefox.lsapi.services.json {
    MessageJsonHandler,
    StreamMessageReader,
    StreamMessageWriter
}
import io.typefox.lsapi.services.transport.server {
    LanguageServerEndpoint
}
import io.typefox.lsapi.services.transport.trace {
    MessageTracer
}

import java.net {
    Socket
}

shared void run() {
    setLogPriority(process.arguments[1]);

    value port
        =   if (exists port = process.arguments[0])
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
    value ceylonLanguageServer = CeylonLanguageServer();
    value endpoint = LanguageServerEndpoint(ceylonLanguageServer);

    endpoint.setMessageTracer(
        object satisfies MessageTracer {
            shared actual void onError(String? s, Throwable? throwable) {
                log.error("(onError) ``s else ""``", throwable);
            }
            shared actual void onRead(Message? message, String? s) {
                value mm = message?.string else "<null>";
                value ss = s else "<null>";
                log.trace("(onRead) ``mm``, ``ss``");
            }
            shared actual void onWrite(Message? message, String? s) {
                value mm = message?.string else "<null>";
                value ss = s else "<null>";
                log.trace("(onWrite) ``mm``, ``ss``");
            }
        }
    );

    reader.setOnError(consumer((Throwable t) => log.error(t.string, t)));
    writer.setOnError(consumer((Throwable t) => log.error(t.string, t)));

    log.info("calling endpoint.connect()");
    endpoint.connect(reader, writer);
    log.info("run() finished");
}
