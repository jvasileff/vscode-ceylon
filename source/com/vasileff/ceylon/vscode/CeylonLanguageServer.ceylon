import java.util.\ifunction {
    Consumer
}
import java.util.concurrent {
    CompletableFuture
}
import io.typefox.lsapi.services {
    LanguageServer,
    TextDocumentService,
    WorkspaceService,
    WindowService
}
import java.util {
    List
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
    RenameParams
}
class CeylonLanguageServer() satisfies LanguageServer {

    shared actual void exit() {}

    shared actual CompletableFuture<InitializeResult> initialize(InitializeParams? initializeParams) => nothing;

    shared actual void onTelemetryEvent(Consumer<Object>? consumer) {}

    shared actual void shutdown() {}

    textDocumentService => object satisfies TextDocumentService {

        shared actual CompletableFuture<List<out Command>> codeAction(CodeActionParams? codeActionParams) => nothing;

        shared actual CompletableFuture<List<out CodeLens>> codeLens(CodeLensParams? codeLensParams) => nothing;

        shared actual CompletableFuture<CompletionList> completion(TextDocumentPositionParams? textDocumentPositionParams) => nothing;

        shared actual CompletableFuture<List<out Location>> definition(TextDocumentPositionParams? textDocumentPositionParams) => nothing;

        shared actual void didChange(DidChangeTextDocumentParams? didChangeTextDocumentParams) {}

        shared actual void didClose(DidCloseTextDocumentParams? didCloseTextDocumentParams) {}

        shared actual void didOpen(DidOpenTextDocumentParams that) {
            print("Opened uri ``that.uri``");
        }

        shared actual void didSave(DidSaveTextDocumentParams? didSaveTextDocumentParams) {}

        shared actual CompletableFuture<DocumentHighlight> documentHighlight(TextDocumentPositionParams? textDocumentPositionParams) => nothing;

        shared actual CompletableFuture<List<out SymbolInformation>> documentSymbol(DocumentSymbolParams? documentSymbolParams) => nothing;

        shared actual CompletableFuture<List<out TextEdit>> formatting(DocumentFormattingParams? documentFormattingParams) => nothing;

        shared actual CompletableFuture<Hover> hover(TextDocumentPositionParams? textDocumentPositionParams) => nothing;

        shared actual void onPublishDiagnostics(Consumer<PublishDiagnosticsParams>? consumer) {}

        shared actual CompletableFuture<List<out TextEdit>> onTypeFormatting(DocumentOnTypeFormattingParams? documentOnTypeFormattingParams) => nothing;

        shared actual CompletableFuture<List<out TextEdit>> rangeFormatting(DocumentRangeFormattingParams? documentRangeFormattingParams) => nothing;

        shared actual CompletableFuture<List<out Location>> references(ReferenceParams? referenceParams) => nothing;

        shared actual CompletableFuture<WorkspaceEdit> rename(RenameParams? renameParams) => nothing;

        shared actual CompletableFuture<CodeLens> resolveCodeLens(CodeLens? codeLens) => nothing;

        shared actual CompletableFuture<CompletionItem> resolveCompletionItem(CompletionItem? completionItem) => nothing;

        shared actual CompletableFuture<SignatureHelp> signatureHelp(TextDocumentPositionParams? textDocumentPositionParams) => nothing;
    };

    windowService => object satisfies WindowService {

        shared actual void onLogMessage(Consumer<MessageParams>? consumer) {}

        shared actual void onShowMessage(Consumer<MessageParams>? consumer) {}

        shared actual void onShowMessageRequest(Consumer<ShowMessageRequestParams>? consumer) {}
    };

    workspaceService => object satisfies WorkspaceService {

        shared actual void didChangeConfiguraton(DidChangeConfigurationParams? didChangeConfigurationParams) {}

        shared actual void didChangeWatchedFiles(DidChangeWatchedFilesParams? didChangeWatchedFilesParams) {}

        shared actual CompletableFuture<List<out SymbolInformation>> symbol(WorkspaceSymbolParams? workspaceSymbolParams) => nothing;
    };
}