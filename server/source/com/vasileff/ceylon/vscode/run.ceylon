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

import java.lang {
    System,
    NullPointerException
}
import java.util.\ifunction {
    Consumer
}

shared void run() {
    value handler = MessageJsonHandler();
    value reader = StreamMessageReader(System.\iin, handler);
    value writer = StreamMessageWriter(System.\iout, handler);
    value ceylonLanguageServer = CeylonLanguageServer();
    value endpoint = LanguageServerEndpoint(ceylonLanguageServer);

    endpoint.setMessageTracer(
        object satisfies MessageTracer {
            shared actual void onError(String? s, Throwable? throwable) {}
            shared actual void onRead(Message? message, String? s) {}
            shared actual void onWrite(Message? message, String? s) {}
        }
    );

    reader.setOnError(consumer((Throwable? t) => noop()));
    writer.setOnError(consumer<Throwable>(noop));

    endpoint.connect(reader, writer);

    print("Connection closed");
}
