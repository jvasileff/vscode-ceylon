import java.lang {
    Error
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

"Alias for all `java.lang.Error`s, of which `AssertionError` is one at runtime for
 non-Ceylon code, which fakes the inheritance away."
alias JavaError => Error | AssertionError;

class WrappedError(JavaError error) extends Exception(null, error) {}

"A wraper for [[LanguageServer]]s that catches [[AssertionError]]s and [[Error]]s and
 rethrows them as [[WrappedError]]s. This is necessary, since `java.lang.Error`s are not
 caught by the framework and basically hose the server."
class LanguageServerWrapper(LanguageServer & LanguageClientAware delegate)
        satisfies LanguageServer & LanguageClientAware {

    shared actual void connect(LanguageClient languageClient) {
        try {
            delegate.connect(languageClient);
        }
        catch (Error | AssertionError e) {
            throw WrappedError(e);
        }
    }

    shared actual void exit() {
        try {
            delegate.exit();
        }
        catch (Error | AssertionError e) {
            throw WrappedError(e);
        }
    }

    shared actual CompletableFuture<InitializeResult>? initialize
            (InitializeParams? that) {
        try {
            return delegate.initialize(that);
        }
        catch (Error | AssertionError e) {
            throw WrappedError(e);
        }
    }

    shared actual CompletableFuture<Object> shutdown() {
        try {
            return delegate.shutdown();
        }
        catch (Error | AssertionError e) {
            throw WrappedError(e);
        }
    }

    shared actual TextDocumentService? textDocumentService =>
            let (delegate = this.delegate.textDocumentService else null)
            if (!exists delegate) then null else object
            satisfies TextDocumentService {

        shared actual CompletableFuture<List<out Command>>? codeAction
                (CodeActionParams? that) {
            try {
                return delegate.codeAction(that);
            }
            catch (Error | AssertionError e) {
                throw WrappedError(e);
            }
        }

        shared actual CompletableFuture<List<out CodeLens>>? codeLens
                (CodeLensParams? that) {
            try {
                return delegate.codeLens(that);
            }
            catch (Error | AssertionError e) {
                throw WrappedError(e);
            }
        }

        shared actual CompletableFuture<CompletionList>? completion
                (TextDocumentPositionParams? that) {
            try {
                return delegate.completion(that);
            }
            catch (Error | AssertionError e) {
                throw WrappedError(e);
            }
        }

        shared actual CompletableFuture<List<out Location>>? definition
                (TextDocumentPositionParams? that) {
            try {
                return delegate.definition(that);
            }
            catch (Error | AssertionError e) {
                throw WrappedError(e);
            }
        }

        shared actual void didChange
                (DidChangeTextDocumentParams? that) {
            try {
                delegate.didChange(that);
            }
            catch (Error | AssertionError e) {
                throw WrappedError(e);
            }
        }

        shared actual void didClose
                (DidCloseTextDocumentParams? that) {
            try {
                delegate.didClose(that);
            }
            catch (Error | AssertionError e) {
                throw WrappedError(e);
            }
        }

        shared actual void didOpen
                (DidOpenTextDocumentParams? that) {
            try {
                delegate.didOpen(that);
            }
            catch (Error | AssertionError e) {
                throw WrappedError(e);
            }
        }

        shared actual void didSave
                (DidSaveTextDocumentParams? that) {
            try {
                delegate.didSave(that);
            }
            catch (Error | AssertionError e) {
                throw WrappedError(e);
            }
        }

        shared actual CompletableFuture<List<out DocumentHighlight>>? documentHighlight
                (TextDocumentPositionParams? that) {
            try {
                return delegate.documentHighlight(that);
            }
            catch (Error | AssertionError e) {
                throw WrappedError(e);
            }
        }

        shared actual CompletableFuture<List<out SymbolInformation>>? documentSymbol
                (DocumentSymbolParams? that) {
            try {
                return delegate.documentSymbol(that);
            }
            catch (Error | AssertionError e) {
                throw WrappedError(e);
            }
        }

        shared actual CompletableFuture<List<out TextEdit>>? formatting
                (DocumentFormattingParams? that) {
            try {
                return delegate.formatting(that);
            }
            catch (Error | AssertionError e) {
                throw WrappedError(e);
            }
        }

        shared actual CompletableFuture<Hover>? hover
                (TextDocumentPositionParams? that) {
            try {
                return delegate.hover(that);
            }
            catch (Error | AssertionError e) {
                throw WrappedError(e);
            }
        }

        shared actual CompletableFuture<List<out TextEdit>>? onTypeFormatting
                (DocumentOnTypeFormattingParams? that) {
            try {
                return delegate.onTypeFormatting(that);
            }
            catch (Error | AssertionError e) {
                throw WrappedError(e);
            }
        }

        shared actual CompletableFuture<List<out TextEdit>>? rangeFormatting
                (DocumentRangeFormattingParams? that) {
            try {
                return delegate.rangeFormatting(that);
            }
            catch (Error | AssertionError e) {
                throw WrappedError(e);
            }
        }

        shared actual CompletableFuture<List<out Location>>? references
                (ReferenceParams? that) {
            try {
                return delegate.references(that);
            }
            catch (Error | AssertionError e) {
                throw WrappedError(e);
            }
        }

        shared actual CompletableFuture<WorkspaceEdit>? rename
                (RenameParams? that) {
            try {
                return delegate.rename(that);
            }
            catch (Error | AssertionError e) {
                throw WrappedError(e);
            }
        }

        shared actual CompletableFuture<CodeLens>? resolveCodeLens
                (CodeLens? that) {
            try {
                return delegate.resolveCodeLens(that);
            }
            catch (Error | AssertionError e) {
                throw WrappedError(e);
            }
        }

        shared actual CompletableFuture<CompletionItem>? resolveCompletionItem
                (CompletionItem? that) {
            try {
                return delegate.resolveCompletionItem(that);
            }
            catch (Error | AssertionError e) {
                throw WrappedError(e);
            }
        }

        shared actual CompletableFuture<SignatureHelp>? signatureHelp
                (TextDocumentPositionParams? that) {
            try {
                return delegate.signatureHelp(that);
            }
            catch (Error | AssertionError e) {
                throw WrappedError(e);
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
            catch (Error | AssertionError e) {
                throw WrappedError(e);
            }
        }

        shared actual void didChangeWatchedFiles
                (DidChangeWatchedFilesParams? that) {
            try {
                delegate.didChangeWatchedFiles(that);
            }
            catch (Error | AssertionError e) {
                throw WrappedError(e);
            }
        }

        shared actual CompletableFuture<List<out SymbolInformation>>? symbol
                (WorkspaceSymbolParams? that) {
            try {
                return delegate.symbol(that);
            }
            catch (Error | AssertionError e) {
                throw WrappedError(e);
            }
        }

    };

// FIXME error handling?
//    shared actual void onError(String? s, Throwable? throwable) {
//        try {
//            delegate.onError(s, throwable);
//        }
//        catch (Error | AssertionError e) {
//            throw WrappedError(e);
//        }
//    }
//
//    shared actual void onRead(Message? message, String? s) {
//        try {
//            delegate.onRead(message, s);
//        }
//        catch (Error | AssertionError e) {
//            throw WrappedError(e);
//        }
//    }
//
//    shared actual void onWrite(Message? message, String? s) {
//        try {
//            delegate.onWrite(message, s);
//        }
//        catch (Error | AssertionError e) {
//            throw WrappedError(e);
//        }
//    }
}