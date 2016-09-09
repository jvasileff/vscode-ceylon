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
    JsonObject
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
    TextDocumentSyncKind
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

    suppressWarnings("unusedDeclaration")
    value ceylonSettings
        =>  if (is JsonObject settings = settings)
            then settings.getObjectOrNull("ceylon")
            else null;

    shared actual
    void exit() {
        log("exit called");
    }

    shared actual
    CompletableFuture<InitializeResult> initialize(InitializeParams that) {
        log("initialize called");

        if (exists rootPath = that.rootPath) {
            log("rootPath is ``rootPath``");
            workspaceRoot = Paths.get(that.rootPath).toAbsolutePath().normalize();
        }
        else {
            log("no root path provided");
        }

        value result = InitializeResultImpl();
        value capabilities = ServerCapabilitiesImpl();

        capabilities.textDocumentSync = TextDocumentSyncKind.full;
        capabilities.completionProvider = CompletionOptionsImpl();
        result.capabilities = capabilities;

        return CompletableFuture.completedFuture<InitializeResult>(result);
    }

    shared actual
    void onTelemetryEvent(Consumer<Object>? consumer) {}

    shared actual
    void shutdown()
        =>  log("shutdown called");

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
            textDocuments[that.textDocument.uri.string] = that.contentChanges.get(0).text;
            queueDiagnotics(that.textDocument.uri);
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
        value diagnostics = compileFile(documentText);
        value p = PublishDiagnosticsParamsImpl();
        p.uri = uri;
        p.diagnostics = JavaList(diagnostics);
        publishDiagnostics.accept(p);
    }
}
