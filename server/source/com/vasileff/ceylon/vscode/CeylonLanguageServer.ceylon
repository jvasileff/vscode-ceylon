import ceylon.buffer.charset {
    utf8
}
import ceylon.file {
    parsePath,
    Directory,
    Visitor,
    File,
    Path
}
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
import ceylon.logging {
    error
}

class CeylonLanguageServer() satisfies LanguageServer {

    late Consumer<PublishDiagnosticsParams> publishDiagnostics;
    late Consumer<MessageParams> logMessage;
    late Consumer<MessageParams> showMessage;
    late Consumer<ShowMessageRequestParams> showMessageRequest;
    late Directory rootDirectory;
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

        if (exists rootPathString = that.rootPath) {
            log.info("rootPath is ``rootPathString``");
            // TODO make sure normalize is what we want. Don't resolve symlinks
            value rootPath = parsePath(rootPathString).absolutePath.normalizedPath;
            value rootDirectory = rootPath.resource;
            if (is Directory rootDirectory) {
                this.rootDirectory = rootDirectory;
                initializeDocuments(rootDirectory);
                textDocuments.each((documentId->_) => queueDiagnotics(documentId));
            }
            else {
                log.error("the root path '``rootPathString``' is not a directory");
            }
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
            assert (exists text
                    =   textDocuments[toDocumentIdString(that.textDocument.uri)]);
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
            value documentId = toDocumentIdString(that.textDocument.uri);
            value existingText = textDocuments[documentId];
            if (!exists existingText) {
                log.error("did not find changed document ``documentId``");
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
            textDocuments[documentId] = newText;
            queueDiagnotics(documentId);
        }

        shared actual
        void didClose(DidCloseTextDocumentParams that) {
            // TODO for "single file mode", will need to remove closed documents
            //textDocuments.remove(that.textDocument.uri.string);
        }

        shared actual
        void didOpen(DidOpenTextDocumentParams that) {
            value documentId = toDocumentIdString(that.textDocument.uri);

            value existingText = textDocuments[documentId];
            if (!exists existingText) {
                log.error("did not find document to open ``documentId``");
                return;
            }
            // this should match what we have, except possible LF vs. CRLF differences
            if (log.enabled(error)) {
                if (!corresponding(existingText.lines, that.textDocument.text.lines)) {
                    log.error("existing text does not match opened text for \
                               ``documentId`` \
                               \n existing: '``existingText``'\
                               \n new     : '``that.textDocument.text``'");
                    textDocuments[documentId] = that.textDocument.text;
                }
            }
            // TODO for "single file mode", will need to queue diagnostics
            //queueDiagnotics(documentId);
        }

        shared actual
        void didSave(DidSaveTextDocumentParams that) {
            // TODO no need, right?
            //queueDiagnotics(toDocumentIdString(that.textDocument.uri));
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
        }

        shared actual
        void didChangeWatchedFiles(DidChangeWatchedFilesParams that) {}

        shared actual
        CompletableFuture<List<out SymbolInformation>>? symbol(WorkspaceSymbolParams that)
            =>  null;
    };

    void queueDiagnotics(String documentId) {
        typeCheckQueue.add(documentId);
        launchCompiler();
    }

    void launchCompiler() {
        if (typeCheckQueue.empty) {
            return;
        }

        // launch a compile task if one isn't running
        if (compiling.compareAndSet(false, true)) {
            log.debug("launching compiler");
            CompletableFuture.runAsync(runnable {
                void run() {
                    try {
                        while (exists documentId = typeCheckQueue.first) {
                            typeCheckQueue.remove(documentId);
                            if (exists text = textDocuments[documentId]) {
                                compileAndPublishDiagnostics(documentId, text);
                            }
                            else {
                                log.error("no text existed for '``documentId``'");
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

    void compileAndPublishDiagnostics(String documentId, String documentText) {
        try {
            value name = if (exists i = documentId.lastOccurrence('/'))
                         then documentId[i+1...]
                         else documentId;
            value diagnostics = compileFile(name, documentText);
            value p = PublishDiagnosticsParamsImpl();
            p.uri = toUri(documentId);
            p.diagnostics =JavaList(diagnostics);
            publishDiagnostics.accept(p);
        }
        catch (Exception | AssertionError e) {
            publishDiagnostics.accept(
                PublishDiagnosticsParamsImpl(toUri(documentId), JavaList(
                    [newDiagnostic {
                        message = e.string;
                        severity = DiagnosticSeverity.error;
                    }])
                )
            );
        }
    }

    String toDocumentIdString(String | Path uri) {
        // FIXME what about multiple source directories?
        //       for now, format is 'source/com/example/file.ceylon'
        value path
            =   if (is Path uri)
                    then uri
                else if (uri.startsWith("file:///"))
                    // we need the "right kind" of path
                    then parsePath(uri[7...])
                else parsePath(uri);

        return path.relativePath(rootDirectory.path).string;
    }

    //see(`function toDocumentIdString`)
    String toUri(String documentId)
        =>  "file://" + rootDirectory.path.childPath(documentId)
                .absolutePath.normalizedPath.string;

    void initializeDocuments(Directory rootDirectory) {
        // TODO discover source directories based on .ceylon/config
        //      and module.ceylon files.
        value sourceDirectory = rootDirectory.path.childPath("source").resource;
        if (!is Directory sourceDirectory) {
            log.error("cannot found 'source' in the root path '``rootDirectory.path``'");
            return;
        }
        // now, read all '*.ceylon' and '*.dart' files into memory!
        sourceDirectory.path.visit(object extends Visitor() {
            shared actual void file(File file) {
                value extension
                    =   if (exists dot = file.name.lastOccurrence('.'))
                        then file.name[dot+1...]
                        else "";
                if (extension in ["ceylon", "dart", "js", "java"]) {
                    value documentId = toDocumentIdString(file.path);
                    textDocuments.put(documentId, readFile(file));
                    log.info("initializing file ``documentId``");
                }
            }
        });
    }
}

String readFile(File file) {
    // we can't use ceylon.file::lines() because it doesn't retain the trailing
    // newline, if one exists.
    try (reader = file.Reader()) {
        value decoder = utf8.cumulativeDecoder();
        while (nonempty bytes = reader.readBytes(100)) {
            decoder.more(bytes);
        }
        return decoder.done().string;
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
    //log.trace(() => "\n'``sb.string``'");
    return sb.string;
}
