import ceylon.collection {
    HashMap
}
import ceylon.interop.java {
    JavaList
}

import com.vasileff.ceylon.vscode.internal {
    forceWrapJavaJson,
    JsonValue,
    log,
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
    MessageType,
    TextDocumentSyncKind,
    DiagnosticSeverity,
    MarkedString
}
import io.typefox.lsapi.builders {
    CompletionListBuilder,
    CompletionItemBuilder,
    HoverBuilder
}
import io.typefox.lsapi.impl {
    InitializeResultImpl,
    ServerCapabilitiesImpl,
    PublishDiagnosticsParamsImpl,
    CompletionOptionsImpl,
    MarkedStringImpl
}
import io.typefox.lsapi.services {
    LanguageServer,
    TextDocumentService,
    WorkspaceService,
    WindowService
}

import java.lang {
    JBoolean=Boolean
}
import java.nio.file {
    Paths,
    Path
}
import java.util {
    List
}
import java.util.concurrent {
    CompletableFuture
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

    value textDocuments = HashMap<String, String>();

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
        capabilities.setHoverProvider(JBoolean.true);
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
            // FIXME will didChange ever happen before didOpen ???
            //       what is VersionedTextDocumentIdentifier?
            textDocuments[that.textDocument.uri.string] = that.contentChanges.get(0).text;
            performDiagnostics(that.textDocument.uri, that.contentChanges.get(0).text);
        }

        shared actual
        void didClose(DidCloseTextDocumentParams that) {
            textDocuments.remove(that.textDocument.uri.string);
        }

        shared actual
        void didOpen(DidOpenTextDocumentParams that) {
            textDocuments[that.textDocument.uri.string] = that.textDocument.text;
            performDiagnostics(that.textDocument.uri, that.textDocument.text);
        }

        shared actual
        void didSave(DidSaveTextDocumentParams that) {}

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
        CompletableFuture<Hover> hover(TextDocumentPositionParams that) {
            value lineChar = "``that.position.line``:``that.position.character``";
            value builder = HoverBuilder();
            builder.content(
                MarkedStringImpl(MarkedString.plainString,
                "You're *cursor* **position** is ```lineChar```"));
            return CompletableFuture.completedFuture(builder.build());
        }

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
            textDocuments.each((uri->text) => performDiagnostics(uri, text));
        }

        shared actual
        void didChangeWatchedFiles(DidChangeWatchedFilesParams that) {}

        shared actual
        CompletableFuture<List<out SymbolInformation>>? symbol(WorkspaceSymbolParams that)
            =>  null;
    };

    void performDiagnostics(String uri, String documentText) {
        // Note: Be sure to send [] to clear all diagnostics if nec. Better would be
        //       to send a diff, if possible.

        value configuredErrorWord
            =   ceylonSettings?.getStringOrNull("errorWord");

        value errorWord
            =   if (exists configuredErrorWord, !configuredErrorWord.empty)
                then configuredErrorWord
                else "nothing";

        value errorWordSize
            =   errorWord.size;

        value diagnostics = JavaList(
            documentText.lines.indexed.flatMap((i->line)
                =>  line.inclusions(errorWord).map((col)
                    =>  newDiagnostic {
                            message = "Are you *sure* you want to use ```errorWord```?
                                       (Bad idea!)";
                            severity = DiagnosticSeverity.error;
                            range = newRange {
                                start = newPosition(i, col);
                                end = newPosition(i, col + errorWordSize);
                            };
                        })).sequence());

        if (!diagnostics.empty) {
            logMessage.accept(newMessageParams {
                "Whoa, you shouldn't use ``errorWord``!";
                MessageType.error;
            });
        }

        value p = PublishDiagnosticsParamsImpl();
        p.uri = uri;
        p.diagnostics = diagnostics;
        publishDiagnostics.accept(p);
    }
}
