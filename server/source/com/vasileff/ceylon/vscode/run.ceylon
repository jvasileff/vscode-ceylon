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
    value [port, priority, configPrefix] = parseArguments(arguments);

    setLogPriority(priority);

    if (!is Integer port) {
        log.fatal("error: no port specified");
        throw Exception("no port specified");
    }

    value socket = Socket("localhost", port);
    log.info("connected to parent using socket on port ``port``");

    value ceylonLanguageServer
        =   CeylonLanguageServer();

    ceylonLanguageServer.configPrefix
        =   configPrefix;

    value languageServer
        =   LanguageServerWrapper(ceylonLanguageServer);

    value launcher
        =   LSPLauncher.createServerLauncher(
                languageServer,
                socket.inputStream,
                socket.outputStream,
                Executors.newCachedThreadPool(),
                (MessageConsumer consumer) {
                    return object satisfies MessageConsumer {
                        shared actual void consume(Message m) {
                            log.trace(()=>"``className(m)`` ``m.string``");
                            try {
                                consumer.consume(m);
                            }
                            catch (Throwable t) {
                                log.fatal("Found this one... NBD.", t);
                                throw t;
                            }
                        }
                    };
                });

    ceylonLanguageServer.connect(launcher.remoteProxy);

    log.info("calling launcher.startListening()");

    try {
        launcher.startListening();
    }
    catch (Throwable t) {
        log.fatal("Fatal error", t);
        throw t;
    }
    finally {
        log.info("run() finished");
    }
}

"Returns port, logPriority, and configPrefix"
[Integer|ParseException?, String?, String?]
        parseArguments([String*] arguments) {
    // TODO proper CLI parsing
    // For now,
    //      - an optional --config-prefix x
    //      - first bare args args are port and log priority
    variable value nextIsCp = false;
    variable String? configPrefix = null;
    variable Integer|ParseException? port = null;
    variable String? logPriority = null;
    for (arg in arguments) {
        if (nextIsCp) {
            nextIsCp = false;
            configPrefix = arg;
        }
        else if (arg == "--config-prefix") {
            nextIsCp = true;
            configPrefix = arg;
        }
        else if (!port exists) {
            port = Integer.parse(arg);
        }
        else if (!logPriority exists) {
            logPriority = arg;
        }
        else {
            throw Exception("Too many arguments!");
        }
    }
    return [port, logPriority, configPrefix];
}
