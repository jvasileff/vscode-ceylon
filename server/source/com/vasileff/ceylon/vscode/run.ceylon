import java.net {
    Socket
}
import java.util.concurrent {
    Executors
}

import org.eclipse.lsp4j.jsonrpc {
    MessageConsumer
}
import org.eclipse.lsp4j.jsonrpc.messages {
    Message
}
import org.eclipse.lsp4j.launch {
    LSPLauncher
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

shared void qr()
    =>  runApp(["55747", "trace"]);

void runApp([String*] arguments) {
    setLogPriority(arguments[1]);

    value port
        =   if (exists port = arguments[0])
            then Integer.parse(port)
            else null;

    if (!is Integer port) {
        log.fatal("error: no port specified");
        throw Exception("no port specified");
    }

    value socket = Socket("localhost", port);
    log.info("connected to parent using socket on port ``port``");

    value ceylonLanguageServer
        =   LanguageServerWrapper(CeylonLanguageServer());

    value launcher
        =   LSPLauncher.createServerLauncher(
                ceylonLanguageServer,
                socket.inputStream,
                socket.outputStream,
                Executors.newCachedThreadPool(),
                (MessageConsumer consumer) {
                    return object satisfies MessageConsumer {
                        shared actual void consume(Message m) {
                            log.trace(()=>"``className(m)`` ``m.string``");
                            consumer.consume(m);
                        }
                    };
                });

    ceylonLanguageServer.connect(launcher.remoteProxy);

// FIXME error handling?
    //reader.setOnError(consumer((Throwable t) => log.error(t.string, t)));
    //writer.setOnError(consumer((Throwable t) => log.error(t.string, t)));

    log.info("calling launcher.startListening()");
    try {
        launcher.startListening();
        //endpoint.connect(reader, writer);
    }
    catch (Throwable t) {
        log.fatal("Fatal error", t);
        throw t;
    }
    finally {
        log.info("run() finished");
    }
}
