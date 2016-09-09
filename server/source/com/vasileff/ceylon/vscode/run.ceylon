import com.vasileff.ceylon.vscode.internal {
    log,
    consumer
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
    value port
        =   if (exists port = process.arguments[0])
            then parseInteger(port)
            else null;

    if (!exists port) {
        log("error: no port specified.");
        throw Exception("No port specified");
    }

    value socket = Socket("localhost", port);
    log("connected to parent using socket on port ``port``");

    value handler = MessageJsonHandler();
    value reader = StreamMessageReader(socket.inputStream, handler);
    value writer = StreamMessageWriter(socket.outputStream, handler);
    value ceylonLanguageServer = CeylonLanguageServer();
    value endpoint = LanguageServerEndpoint(ceylonLanguageServer);

    endpoint.setMessageTracer(
        object satisfies MessageTracer {
            shared actual void onError(String? s, Throwable? throwable) {
                value ss = s else "<null>";
                value tt = throwable?.string else "<null>";
                log("tracer.error: ``ss``, ``tt``");
            }
            shared actual void onRead(Message? message, String? s) {
                value mm = message?.string else "<null>";
                value ss = s else "<null>";
                log("tracer.read: ``mm``, ``ss``");
            }
            shared actual void onWrite(Message? message, String? s) {
                value mm = message?.string else "<null>";
                value ss = s else "<null>";
                log("tracer.write: ``mm``, ``ss``");
            }
        }
    );

    reader.setOnError(consumer((Throwable t) => log("reader error: " + t.string)));
    writer.setOnError(consumer((Throwable t) => log("writer error: " + t.string)));

    log("Calling endpoint.connect()");
    endpoint.connect(reader, writer);

    log("Done.");
}
