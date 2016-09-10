import ceylon.interop.java {
    JavaList,
    CeylonMutableMap,
    CeylonMutableSet
}

import com.vasileff.ceylon.vscode.internal {
    forceWrapJavaJson,
    JsonValue,
    log,
    runnable,
    JsonObject,
    newDiagnostic,
    setLogPriority
}

import io.typefox.lsapi {
    CodeActionParams,
    MessageParams,
    InitializeParams,
    TextEdit,
    DidOpenTextDocumentParams,
    TextDocumentPositionParams,
    CodeLensParams,
    ReferenceParams,
    CompletionList,
    PublishDiagnosticsParams,
    DidSaveTextDocumentParams,
    DidChangeTextDocumentParams,
    DocumentHighlight,
    DocumentSymbolParams,
    SignatureHelp,
    SymbolInformation,
    CodeLens,
    Command,
    ShowMessageRequestParams,
    DocumentFormattingParams,
    CompletionItem,
    DidCloseTextDocumentParams,
    DidChangeWatchedFilesParams,
    Location,
    WorkspaceSymbolParams,
    Hover,
    WorkspaceEdit,
    DocumentOnTypeFormattingParams,
    DidChangeConfigurationParams,
    DocumentRangeFormattingParams,
    InitializeResult,
    RenameParams,
    TextDocumentSyncKind,
    DiagnosticSeverity,
    Range
}
import io.typefox.lsapi.builders {
    CompletionListBuilder,
    CompletionItemBuilder
}
import io.typefox.lsapi.impl {
    InitializeResultImpl,
    ServerCapabilitiesImpl,
    PublishDiagnosticsParamsImpl,
    CompletionOptionsImpl
}
import io.typefox.lsapi.services {
    LanguageServer,
    TextDocumentService,
    WorkspaceService,
    WindowService
}

import java.nio.file {
    Paths,
    Path
}
import java.util {
    List
}
import java.util.concurrent {
    CompletableFuture,
    ConcurrentHashMap
}
import java.util.concurrent.atomic {
    AtomicBoolean
}
import java.util.\ifunction {
    Consumer
}

class CeylonLanguageServer() satisfies LanguageServer {

    late Consumer<PublishDiagnosticsParams> publishDiagnostics;
    late Consumer<MessageParams> logMessage;
    late Consumer<MessageParams> showMessage;
    late Consumer<ShowMessageRequestParams> showMessageRequest;
    late Path workspaceRoot;
    variable JsonValue settings = null;

    value compiling = AtomicBoolean(false);
    value typeCheckQueue = CeylonMutableSet(ConcurrentHashMap.newKeySet<String>());
    value textDocuments = CeylonMutableMap(ConcurrentHashMap<String, String>());

    value ceylonSettings
        =>  if (is JsonObject settings = settings)
            then settings.getObjectOrNull("ceylon")
            else null;

    shared actual
    void exit() {
        log.info("exit called");
    }

    shared actual
    CompletableFuture<InitializeResult> initialize(InitializeParams that) {
        log.info("initialize called");

        if (exists rootPath = that.rootPath) {
            log.info("rootPath is ``rootPath``");
            workspaceRoot = Paths.get(that.rootPath).toAbsolutePath().normalize();
        }
        else {
            log.info("no root path provided");
        }

        value result = InitializeResultImpl();
        value capabilities = ServerCapabilitiesImpl();

        capabilities.textDocumentSync = TextDocumentSyncKind.incremental;
        capabilities.completionProvider = CompletionOptionsImpl();
        result.capabilities = capabilities;

        return CompletableFuture.completedFuture<InitializeResult>(result);
    }

    shared actual
    void onTelemetryEvent(Consumer<Object>? consumer) {}

    shared actual
    void shutdown()
        =>  log.info("shutdown called");

    shared actual
    TextDocumentService textDocumentService => object
            satisfies TextDocumentService {

        shared actual
        CompletableFuture<List<out Command>>? codeAction(CodeActionParams that)
            =>  null;

        shared actual
        CompletableFuture<List<out CodeLens>>? codeLens(CodeLensParams that)
            =>  null;

        shared actual
        CompletableFuture<CompletionList> completion(TextDocumentPositionParams that) {
            assert (exists text = textDocuments[that.textDocument.uri.string]);
            value lineCharacter = "``that.position.line``:``that.position.character``";
            value builder = CompletionListBuilder();

            builder.item(CompletionItemBuilder()
                .label(lineCharacter)
                .documentation("Docs for lineChar")
                .detail("Detail for lineCharacter").build());

            builder.item(CompletionItemBuilder()
                .label("nothing")
                .documentation("Docs for nothing")
                .detail("Detail for nothing").build());

            return CompletableFuture.completedFuture<CompletionList>(builder.build());
        }

        shared actual
        CompletableFuture<List<out Location>>? definition(TextDocumentPositionParams that)
            =>  null;

        shared actual
        void didChange(DidChangeTextDocumentParams that) {
            value uri = that.textDocument.uri;
            value existingText = textDocuments[uri];
            if (!exists existingText) {
                log.error("did not find changed document ``uri``");
                return;
            }
            variable value newText = existingText;
            for (change in that.contentChanges) {
                switch (range = change.range)
                case (is Null) {
                    newText = change.text;
                }
                else {
                    newText = replaceRange(newText, range, change.text);
                }
            }
            textDocuments[uri] = newText;
            queueDiagnotics(uri);
        }

        shared actual
        void didClose(DidCloseTextDocumentParams that) {
            textDocuments.remove(that.textDocument.uri.string);
        }

        shared actual
        void didOpen(DidOpenTextDocumentParams that) {
            textDocuments[that.textDocument.uri.string] = that.textDocument.text;
            queueDiagnotics(that.textDocument.uri);
        }

        shared actual
        void didSave(DidSaveTextDocumentParams that) {
            queueDiagnotics(that.textDocument.uri);
        }

        shared actual
        CompletableFuture<DocumentHighlight>? documentHighlight
                (TextDocumentPositionParams that)
            =>  null;

        shared actual
        CompletableFuture<List<out SymbolInformation>>? documentSymbol
                (DocumentSymbolParams that)
            =>  null;

        shared actual
        CompletableFuture<List<out TextEdit>>? formatting(DocumentFormattingParams that)
            =>  null;

        shared actual
        CompletableFuture<Hover>? hover(TextDocumentPositionParams that)
            =>  null;

        shared actual
        void onPublishDiagnostics(Consumer<PublishDiagnosticsParams> that)
            =>  publishDiagnostics = that;

        shared actual
        CompletableFuture<List<out TextEdit>>? onTypeFormatting
                (DocumentOnTypeFormattingParams that)
            =>  null;

        shared actual
        CompletableFuture<List<out TextEdit>>? rangeFormatting
                (DocumentRangeFormattingParams that)
            =>  null;

        shared actual
        CompletableFuture<List<out Location>>? references(ReferenceParams that)
            =>  null;

        shared actual
        CompletableFuture<WorkspaceEdit>? rename(RenameParams that)
            =>  null;

        shared actual
        CompletableFuture<CodeLens>? resolveCodeLens(CodeLens that)
            =>  null;

        shared actual
        CompletableFuture<CompletionItem>? resolveCompletionItem(CompletionItem that)
            =>  null;

        shared actual
        CompletableFuture<SignatureHelp>? signatureHelp(TextDocumentPositionParams that)
            =>  null;
    };

    shared actual
    WindowService windowService => object satisfies WindowService {
        shared actual
        void onLogMessage(Consumer<MessageParams> that)
            =>  logMessage = that;

        shared actual
        void onShowMessage(Consumer<MessageParams> that)
            =>  showMessage = that;

        shared actual
        void onShowMessageRequest(Consumer<ShowMessageRequestParams> that)
            =>  showMessageRequest = that;
    };

    shared actual
    WorkspaceService workspaceService => object satisfies WorkspaceService {
        shared actual
        void didChangeConfiguraton(DidChangeConfigurationParams that) {
            settings = forceWrapJavaJson(that.settings);
            // update logging level
            if (exists p = ceylonSettings?.getStringOrNull("serverLogPriority")) {
                setLogPriority(p);
            }
            textDocuments.each((uri->text) => queueDiagnotics(uri));
        }

        shared actual
        void didChangeWatchedFiles(DidChangeWatchedFilesParams that) {}

        shared actual
        CompletableFuture<List<out SymbolInformation>>? symbol(WorkspaceSymbolParams that)
            =>  null;
    };

    void queueDiagnotics(String uri) {
        typeCheckQueue.add(uri);
        launchCompiler();
    }

    void launchCompiler() {
        if (typeCheckQueue.empty) {
            return;
        }

        // launch a compile task if one isn't running
        if (compiling.compareAndSet(false, true)) {
            CompletableFuture.runAsync(runnable {
                void run() {
                    try {
                        while (exists uri = typeCheckQueue.first) {
                            typeCheckQueue.remove(uri);
                            if (exists text = textDocuments[uri]) {
                                compileAndPublishDiagnostics(uri, text);
                            }
                        }
                    }
                    finally {
                        compiling.set(false);
                    }
                }
            });
        }
    }

    void compileAndPublishDiagnostics(String uri, String documentText) {
        try {
            value name = if (exists i = uri.lastOccurrence('/'))
                         then uri[i+1...]
                         else uri;
            value diagnostics = compileFile(name, documentText);
            value p = PublishDiagnosticsParamsImpl();
            p.uri = uri;
            p.diagnostics =JavaList(diagnostics);
            publishDiagnostics.accept(p);
        }
        catch (Exception | AssertionError e) {
            publishDiagnostics.accept(
                PublishDiagnosticsParamsImpl(uri, JavaList(
                    [newDiagnostic {
                        message = e.string;
                        severity = DiagnosticSeverity.error;
                    }])
                )
            );
        }
    }
}

String replaceRange(String text, Range range, String replacementText) {
    // lines are 0 indexed, characters are 1 indexed

    value sb = StringBuilder();
    variable value lineNo = 0;
    value nextLine = text.lines.iterator().next;

    // copy lines before the change
    while (lineNo < range.start.line, is String line = nextLine()) {
        lineNo++;
        sb.append(line);
        sb.appendCharacter('\n');
    }

    // copy the leading portion of the line at the start of the range
    value partialStartLine
        =   switch (line = nextLine())
            case (is Finished) "" else line;
    lineNo++;
    sb.append(partialStartLine[0:range.start.character]);

    // append the replacement
    sb.append(replacementText);

    // copy the trailing portion of the line at the end of the range
    String partialEndLine;
    if (range.start.line == range.end.line) {
        partialEndLine = partialStartLine;
    }
    else {
        // burn discarded lines
        while (lineNo < range.end.line) {
            nextLine();
            lineNo ++;
        }
        partialEndLine
            =   switch (line = nextLine())
                case (is Finished) "" else line;
        lineNo++;
    }
    sb.append(partialEndLine[range.end.character...]);

    // copy lines after the change
    while (!is Finished line = nextLine()) {
        sb.appendCharacter('\n');
        sb.append(line);
    }
    log.debug(() => "\n'``sb.string``'");
    return sb.string;
}
