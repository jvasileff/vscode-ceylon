import java.lang {
    Error,
    RuntimeException
}
import java.util {
    List
}
import java.util.concurrent {
    CompletableFuture
}

import org.eclipse.lsp4j {
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
    DocumentOnTypeFormattingParams,
    DocumentRangeFormattingParams,
    ReferenceParams,
    WorkspaceEdit,
    RenameParams,
    CompletionItem,
    SignatureHelp,
    DidChangeConfigurationParams,
    DidChangeWatchedFilesParams,
    WorkspaceSymbolParams
}
import org.eclipse.lsp4j.services {
    LanguageServer,
    TextDocumentService,
    WorkspaceService,
    LanguageClientAware,
    LanguageClient
}

"A [[LanguageServer]] wrapper that performs exception error handling for all events.
 Both immediate exceptions and exceptions produced by Futures are passed to onError()
 for logging and reporting.

 That this class is necessary since the LSP4J framework does not offer a reasonable way
 for us to provide our own exceptionHandler to the RemoteEndpoint."
class LanguageServerWrapper
        (LanguageServer & LanguageClientAware & ErrorListener delegate)
        satisfies LanguageServer & LanguageClientAware {

    shared actual void connect(LanguageClient languageClient) {
        try {
            delegate.connect(languageClient);
        }
        catch (Throwable t) {
            throw reportAndRethrow(t);
        }
    }

    shared actual void exit() {
        try {
            delegate.exit();
        }
        catch (Throwable t) {
            throw reportAndRethrow(t);
        }
    }

    shared actual CompletableFuture<InitializeResult>? initialize
            (InitializeParams? that) {
        try {
            return addErrorHandling(delegate.initialize(that));
        }
        catch (Throwable t) {
            throw reportAndRethrow(t);
        }
    }

    shared actual CompletableFuture<Object>? shutdown() {
        try {
            return addErrorHandling(delegate.shutdown());
        }
        catch (Throwable t) {
            throw reportAndRethrow(t);
        }
    }

    shared actual TextDocumentService? textDocumentService =>
            let (delegate = this.delegate.textDocumentService else null)
            if (!exists delegate) then null else object
            satisfies TextDocumentService {

        shared actual CompletableFuture<List<out Command>>? codeAction
                (CodeActionParams? that) {
            try {
                return addErrorHandling(delegate.codeAction(that));
            }
            catch (Throwable t) {
                throw reportAndRethrow(t);
            }
        }

        shared actual CompletableFuture<List<out CodeLens>>? codeLens
                (CodeLensParams? that) {
            try {
                return addErrorHandling(delegate.codeLens(that));
            }
            catch (Throwable t) {
                throw reportAndRethrow(t);
            }
        }

        shared actual CompletableFuture<CompletionList>? completion
                (TextDocumentPositionParams? that) {
            try {
                return addErrorHandling(delegate.completion(that));
            }
            catch (Throwable t) {
                throw reportAndRethrow(t);
            }
        }

        shared actual CompletableFuture<List<out Location>>? definition
                (TextDocumentPositionParams? that) {
            try {
                return addErrorHandling(delegate.definition(that));
            }
            catch (Throwable t) {
                throw reportAndRethrow(t);
            }
        }

        shared actual void didChange
                (DidChangeTextDocumentParams? that) {
            try {
                delegate.didChange(that);
            }
            catch (Throwable t) {
                throw reportAndRethrow(t);
            }
        }

        shared actual void didClose
                (DidCloseTextDocumentParams? that) {
            try {
                delegate.didClose(that);
            }
            catch (Throwable t) {
                throw reportAndRethrow(t);
            }
        }

        shared actual void didOpen
                (DidOpenTextDocumentParams? that) {
            try {
                delegate.didOpen(that);
            }
            catch (Throwable t) {
                throw reportAndRethrow(t);
            }
        }

        shared actual void didSave
                (DidSaveTextDocumentParams? that) {
            try {
                delegate.didSave(that);
            }
            catch (Throwable t) {
                throw reportAndRethrow(t);
            }
        }

        shared actual CompletableFuture<List<out DocumentHighlight>>? documentHighlight
                (TextDocumentPositionParams? that) {
            try {
                return addErrorHandling(delegate.documentHighlight(that));
            }
            catch (Throwable t) {
                throw reportAndRethrow(t);
            }
        }

        shared actual CompletableFuture<List<out SymbolInformation>>? documentSymbol
                (DocumentSymbolParams? that) {
            try {
                return addErrorHandling(delegate.documentSymbol(that));
            }
            catch (Throwable t) {
                throw reportAndRethrow(t);
            }
        }

        shared actual CompletableFuture<List<out TextEdit>>? formatting
                (DocumentFormattingParams? that) {
            try {
                return addErrorHandling(delegate.formatting(that));
            }
            catch (Throwable t) {
                throw reportAndRethrow(t);
            }
        }

        shared actual CompletableFuture<Hover>? hover
                (TextDocumentPositionParams? that) {
            try {
                return addErrorHandling(delegate.hover(that));
            }
            catch (Throwable t) {
                throw reportAndRethrow(t);
            }
        }

        shared actual CompletableFuture<List<out TextEdit>>? onTypeFormatting
                (DocumentOnTypeFormattingParams? that) {
            try {
                return addErrorHandling(delegate.onTypeFormatting(that));
            }
            catch (Throwable t) {
                throw reportAndRethrow(t);
            }
        }

        shared actual CompletableFuture<List<out TextEdit>>? rangeFormatting
                (DocumentRangeFormattingParams? that) {
            try {
                return addErrorHandling(delegate.rangeFormatting(that));
            }
            catch (Throwable t) {
                throw reportAndRethrow(t);
            }
        }

        shared actual CompletableFuture<List<out Location>>? references
                (ReferenceParams? that) {
            try {
                return addErrorHandling(delegate.references(that));
            }
            catch (Throwable t) {
                throw reportAndRethrow(t);
            }
        }

        shared actual CompletableFuture<WorkspaceEdit>? rename
                (RenameParams? that) {
            try {
                return addErrorHandling(delegate.rename(that));
            }
            catch (Throwable t) {
                throw reportAndRethrow(t);
            }
        }

        shared actual CompletableFuture<CodeLens>? resolveCodeLens
                (CodeLens? that) {
            try {
                return addErrorHandling(delegate.resolveCodeLens(that));
            }
            catch (Throwable t) {
                throw reportAndRethrow(t);
            }
        }

        shared actual CompletableFuture<CompletionItem>? resolveCompletionItem
                (CompletionItem? that) {
            try {
                return addErrorHandling(delegate.resolveCompletionItem(that));
            }
            catch (Throwable t) {
                throw reportAndRethrow(t);
            }
        }

        shared actual CompletableFuture<SignatureHelp>? signatureHelp
                (TextDocumentPositionParams? that) {
            try {
                return addErrorHandling(delegate.signatureHelp(that));
            }
            catch (Throwable t) {
                throw reportAndRethrow(t);
            }
        }
    };

    shared actual WorkspaceService? workspaceService =>
            let (delegate = this.delegate.workspaceService else null)
            if (!exists delegate) then null else object
            satisfies WorkspaceService {

        shared actual void didChangeConfiguration
                (DidChangeConfigurationParams? that) {
            try {
                delegate.didChangeConfiguration(that);
            }
            catch (Throwable t) {
                throw reportAndRethrow(t);
            }
        }

        shared actual void didChangeWatchedFiles
                (DidChangeWatchedFilesParams? that) {
            try {
                delegate.didChangeWatchedFiles(that);
            }
            catch (Throwable t) {
                throw reportAndRethrow(t);
            }
        }

        shared actual CompletableFuture<List<out SymbolInformation>>? symbol
                (WorkspaceSymbolParams? that) {
            try {
                return addErrorHandling(delegate.symbol(that));
            }
            catch (Throwable t) {
                throw reportAndRethrow(t);
            }
        }
    };

    CompletableFuture<T>? addErrorHandling<T>(CompletableFuture<T>? future) {
        if (exists future) {
            future.whenComplete((Anything r, Throwable? t) => delegate.onError(t));
        }
        return future;
    }

    Throwable reportAndRethrow(Throwable t) {
        delegate.onError(t);
        if (!t is Error | RuntimeException) {
            // The framework expects only RuntimeExceptions
            // unless thrown completing a Future.
            throw RuntimeException(t);
        }
        throw t;
    }
}
