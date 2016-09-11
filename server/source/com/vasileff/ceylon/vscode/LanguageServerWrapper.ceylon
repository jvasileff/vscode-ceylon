import io.typefox.lsapi.services {
    LanguageServer,
    TextDocumentService,
    WindowService,
    WorkspaceService
}
import java.util.\ifunction {
    Consumer
}
import io.typefox.lsapi {
    InitializeResult,
    InitializeParams,
    Command,
    CodeActionParams,
    CodeLens,
    CodeLensParams,
    CompletionList,
    TextDocumentPositionParams,
    Location,
    DidChangeTextDocumentParams,
    DidCloseTextDocumentParams,
    DidOpenTextDocumentParams,
    DidSaveTextDocumentParams,
    DocumentHighlight,
    SymbolInformation,
    DocumentSymbolParams,
    TextEdit,
    DocumentFormattingParams,
    Hover,
    PublishDiagnosticsParams,
    DocumentOnTypeFormattingParams,
    DocumentRangeFormattingParams,
    ReferenceParams,
    WorkspaceEdit,
    RenameParams,
    CompletionItem,
    SignatureHelp,
    MessageParams,
    ShowMessageRequestParams,
    DidChangeConfigurationParams,
    DidChangeWatchedFilesParams,
    WorkspaceSymbolParams
}
import java.util.concurrent {
    CompletableFuture
}
import java.util {
    List
}

class AssertionException(AssertionError error) extends Exception(null, error) {}

"A wraper for [[LanguageServer]]s that catches [[AssertionError]]s and rethrows them
 as [[AssertionException]]s. This is necessary, since `java.lang.Error`s are not caught by
 the framework and basically hose the server."
class LanguageServerWrapper(LanguageServer delegate)
        satisfies LanguageServer {

    shared actual void exit() {
        try {
            delegate.exit();
        }
        catch (AssertionError e) {
            throw AssertionException(e);
        }
    }

    shared actual CompletableFuture<InitializeResult>? initialize
            (InitializeParams? that) {
        try {
            return delegate.initialize(that);
        }
        catch (AssertionError e) {
            throw AssertionException(e);
        }
    }

    shared actual void onTelemetryEvent(Consumer<Object>? that) {
        try {
            delegate.onTelemetryEvent(that);
        }
        catch (AssertionError e) {
            throw AssertionException(e);
        }
    }

    shared actual void shutdown() {}

    shared actual TextDocumentService? textDocumentService =>
            let (delegate = this.delegate.textDocumentService else null)
            if (!exists delegate) then null else object
            satisfies TextDocumentService {

        shared actual CompletableFuture<List<out Command>>? codeAction
                (CodeActionParams? that) {
            try {
                return delegate.codeAction(that);
            }
            catch (AssertionError e) {
                throw AssertionException(e);
            }
        }

        shared actual CompletableFuture<List<out CodeLens>>? codeLens
                (CodeLensParams? that) {
            try {
                return delegate.codeLens(that);
            }
            catch (AssertionError e) {
                throw AssertionException(e);
            }
        }

        shared actual CompletableFuture<CompletionList>? completion
                (TextDocumentPositionParams? that) {
            try {
                return delegate.completion(that);
            }
            catch (AssertionError e) {
                throw AssertionException(e);
            }
        }

        shared actual CompletableFuture<List<out Location>>? definition
                (TextDocumentPositionParams? that) {
            try {
                return delegate.definition(that);
            }
            catch (AssertionError e) {
                throw AssertionException(e);
            }
        }

        shared actual void didChange
                (DidChangeTextDocumentParams? that) {
            try {
                delegate.didChange(that);
            }
            catch (AssertionError e) {
                throw AssertionException(e);
            }
        }

        shared actual void didClose
                (DidCloseTextDocumentParams? that) {
            try {
                delegate.didClose(that);
            }
            catch (AssertionError e) {
                throw AssertionException(e);
            }
        }

        shared actual void didOpen
                (DidOpenTextDocumentParams? that) {
            try {
                delegate.didOpen(that);
            }
            catch (AssertionError e) {
                throw AssertionException(e);
            }
        }

        shared actual void didSave
                (DidSaveTextDocumentParams? that) {
            try {
                delegate.didSave(that);
            }
            catch (AssertionError e) {
                throw AssertionException(e);
            }
        }

        shared actual CompletableFuture<DocumentHighlight>? documentHighlight
                (TextDocumentPositionParams? that) {
            try {
                return delegate.documentHighlight(that);
            }
            catch (AssertionError e) {
                throw AssertionException(e);
            }
        }

        shared actual CompletableFuture<List<out SymbolInformation>>? documentSymbol
                (DocumentSymbolParams? that) {
            try {
                return delegate.documentSymbol(that);
            }
            catch (AssertionError e) {
                throw AssertionException(e);
            }
        }

        shared actual CompletableFuture<List<out TextEdit>>? formatting
                (DocumentFormattingParams? that) {
            try {
                return delegate.formatting(that);
            }
            catch (AssertionError e) {
                throw AssertionException(e);
            }
        }

        shared actual CompletableFuture<Hover>? hover
                (TextDocumentPositionParams? that) {
            try {
                return delegate.hover(that);
            }
            catch (AssertionError e) {
                throw AssertionException(e);
            }
        }

        shared actual void onPublishDiagnostics
                (Consumer<PublishDiagnosticsParams>? that) {
            try {
                delegate.onPublishDiagnostics(that);
            }
            catch (AssertionError e) {
                throw AssertionException(e);
            }
        }

        shared actual CompletableFuture<List<out TextEdit>>? onTypeFormatting
                (DocumentOnTypeFormattingParams? that) {
            try {
                return delegate.onTypeFormatting(that);
            }
            catch (AssertionError e) {
                throw AssertionException(e);
            }
        }

        shared actual CompletableFuture<List<out TextEdit>>? rangeFormatting
                (DocumentRangeFormattingParams? that) {
            try {
                return delegate.rangeFormatting(that);
            }
            catch (AssertionError e) {
                throw AssertionException(e);
            }
        }

        shared actual CompletableFuture<List<out Location>>? references
                (ReferenceParams? that) {
            try {
                return delegate.references(that);
            }
            catch (AssertionError e) {
                throw AssertionException(e);
            }
        }

        shared actual CompletableFuture<WorkspaceEdit>? rename
                (RenameParams? that) {
            try {
                return delegate.rename(that);
            }
            catch (AssertionError e) {
                throw AssertionException(e);
            }
        }

        shared actual CompletableFuture<CodeLens>? resolveCodeLens
                (CodeLens? that) {
            try {
                return delegate.resolveCodeLens(that);
            }
            catch (AssertionError e) {
                throw AssertionException(e);
            }
        }

        shared actual CompletableFuture<CompletionItem>? resolveCompletionItem
                (CompletionItem? that) {
            try {
                return delegate.resolveCompletionItem(that);
            }
            catch (AssertionError e) {
                throw AssertionException(e);
            }
        }

        shared actual CompletableFuture<SignatureHelp>? signatureHelp
                (TextDocumentPositionParams? that) {
            try {
                return delegate.signatureHelp(that);
            }
            catch (AssertionError e) {
                throw AssertionException(e);
            }
        }
    };

    shared actual WindowService? windowService =>
            let (delegate = this.delegate.windowService else null)
            if (!exists delegate) then null else object
            satisfies WindowService {

        shared actual void onLogMessage
                (Consumer<MessageParams>? that) {
            try {
                delegate.onLogMessage(that);
            }
            catch (AssertionError e) {
                throw AssertionException(e);
            }
        }

        shared actual void onShowMessage
                (Consumer<MessageParams>? that) {
            try {
                delegate.onShowMessage(that);
            }
            catch (AssertionError e) {
                throw AssertionException(e);
            }
        }

        shared actual void onShowMessageRequest
                (Consumer<ShowMessageRequestParams>? that) {
            try {
                delegate.onShowMessageRequest(that);
            }
            catch (AssertionError e) {
                throw AssertionException(e);
            }
        }
    };

    shared actual WorkspaceService? workspaceService =>
            let (delegate = this.delegate.workspaceService else null)
            if (!exists delegate) then null else object
            satisfies WorkspaceService {

        shared actual void didChangeConfiguraton
                (DidChangeConfigurationParams? that) {
            try {
                delegate.didChangeConfiguraton(that);
            }
            catch (AssertionError e) {
                throw AssertionException(e);
            }
        }

        shared actual void didChangeWatchedFiles
                (DidChangeWatchedFilesParams? that) {
            try {
                delegate.didChangeWatchedFiles(that);
            }
            catch (AssertionError e) {
                throw AssertionException(e);
            }
        }

        shared actual CompletableFuture<List<out SymbolInformation>>? symbol
                (WorkspaceSymbolParams? that) {
            try {
                return delegate.symbol(that);
            }
            catch (AssertionError e) {
                throw AssertionException(e);
            }
        }

    };
}