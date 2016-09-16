import ceylon.buffer.charset {
    utf8
}
import ceylon.file {
    parsePath,
    Directory,
    Visitor,
    File,
    Path,
    Nil,
    Link
}
import ceylon.interop.java {
    JavaList,
    CeylonMutableMap,
    CeylonMutableSet,
    JavaComparator,
    CeylonIterable
}

import com.redhat.ceylon.common.config {
    DefaultToolOptions,
    CeylonConfig
}
import com.vasileff.ceylon.dart.compiler {
    ReportableException
}
import com.vasileff.ceylon.structures {
    ArrayListMultimap,
    ListMultimap
}
import com.vasileff.ceylon.vscode.internal {
    forceWrapJavaJson,
    JsonValue,
    log,
    runnable,
    JsonObject,
    setLogPriority,
    newMessageParams,
    ReportedException,
    eq,
    LSContext
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
    Range,
    MessageType,
    Message,
    FileChangeType
}
import io.typefox.lsapi.builders {
    CompletionListBuilder,
    CompletionItemBuilder
}
import io.typefox.lsapi.impl {
    InitializeResultImpl,
    ServerCapabilitiesImpl,
    PublishDiagnosticsParamsImpl,
    CompletionOptionsImpl,
    DiagnosticImpl,
    CompletionListImpl,
    CompletionItemImpl
}
import io.typefox.lsapi.services {
    LanguageServer,
    TextDocumentService,
    WorkspaceService,
    WindowService
}
import io.typefox.lsapi.services.transport.trace {
    MessageTracer
}

import java.io {
    JFile=File
}
import java.util {
    List
}
import java.util.concurrent {
    CompletableFuture,
    ConcurrentSkipListMap,
    ConcurrentSkipListSet
}
import java.util.concurrent.atomic {
    AtomicBoolean
}
import java.util.\ifunction {
    Consumer
}
import com.redhat.ceylon.model.typechecker.model {
    Module
}

class CeylonLanguageServer() satisfies LanguageServer & MessageTracer & LSContext {

    // FIXME this is obviously just for initial testing
    shared actual variable Map<String, Module> moduleCache = emptyMap;

    shared actual late Consumer<PublishDiagnosticsParams> publishDiagnostics;
    shared actual late Consumer<MessageParams> logMessage;
    shared actual late Consumer<MessageParams> showMessage;
    shared actual late Consumer<ShowMessageRequestParams> showMessageRequest;
    shared actual late Directory? rootDirectory;
    shared actual variable JsonValue settings = null;
    shared actual variable [String*] sourceDirectories = ["source/"];

    value compiling
        =   AtomicBoolean(false);

    value textDocuments
        =   CeylonMutableMap(ConcurrentSkipListMap<String, String>(
                    JavaComparator(uncurry(String.compare))));

    value openDocuments
        =   CeylonMutableSet(ConcurrentSkipListSet<String>(
                    JavaComparator(uncurry(String.compare))));

    // FIXME ConcurrentSkipListSet.clear() and addAll() are not thread safe, but we're
    //       using it as if they were
    value typeCheckQueue
        =   CeylonMutableSet(ConcurrentSkipListSet<String>(
                    JavaComparator(uncurry(String.compare))));

    value ceylonSettings
        =>  if (is JsonObject settings = settings)
            then settings.getObjectOrNull("ceylon")
            else null;

    function inSourceDirectory(String documentId)
        =>  sourceDirectories.any((d) => documentId.startsWith(d));

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

                // setup source directories

                // TODO make sure the compiler use this config too
                //      Watch .ceylon/config, update the source dir list and rebuild
                //      textDocuments if dirs change

                value ceylonConfig
                    =   CeylonConfig.createFromLocalDir(JFile(that.rootPath));

                value sourceDirectoryJFiles
                    =   CeylonIterable(DefaultToolOptions
                            .getCompilerSourceDirs(ceylonConfig));

                // getCompilerSourceDirs() wraps what was specified .ceylon/config which
                // may include things like './', or may even be an absolute path. So,
                // turn it into an absolute path, and then relativize.
                sourceDirectories
                    =   sourceDirectoryJFiles.map((jFile) {
                            value relativePath
                                =   rootPath.childPath(jFile.path)
                                        .absolutePath.normalizedPath
                                        .relativePath(rootPath)
                                        .string + "/";
                            if (relativePath.startsWith(".")) {
                                // This can happen when the source path involves symbolic
                                // links. We could resolve the source path and try again,
                                // but not worth it. (Note that VSCode tends to resolve
                                // links when providing 'that.rootPath'.)
                                value message
                                    =   "unable to relativize source directory \
                                         '``jFile``' to the workspace path \
                                         '``rootPathString``'; see .ceylon/config";
                                showMessage.accept(newMessageParams {
                                    message = message;
                                    type = MessageType.error;
                                });
                                log.error(message);
                                return null;
                            }
                            return relativePath;
                        }).coalesced.sequence();

                log.info("configured source directories: ``sourceDirectories``");

                // read sourcefiles into memory
                initializeDocuments(rootDirectory);

                // launch initial compile
                queueDiagnotics(*textDocuments.keys);
            }
            else {
                throw ReportableException(
                        "the root path '``rootPathString``' is not a directory");
            }
        }
        else {
            this.rootDirectory = null;
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

    exit() => log.info("exit called");

    shutdown() => log.info("shutdown called");

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
            value documentId = toDocumentIdString(that.textDocument.uri);

            if (!inSourceDirectory(documentId)) {
                // Senda an empty completion list for non-source files
                value result = CompletionListImpl();
                result.items = JavaList<CompletionItemImpl>([]);
                return CompletableFuture.completedFuture<CompletionList>(result);
            }

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

            if (!inSourceDirectory(documentId)) {
                return;
            }

            value existingText = textDocuments[documentId];
            if (!exists existingText) {
                throw ReportableException("did not find changed document \
                                           '``documentId``'");
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
            value documentId = toDocumentIdString(that.textDocument.uri);
            openDocuments.remove(documentId);
        }

        shared actual
        void didOpen(DidOpenTextDocumentParams that) {
            // Note that:
            //
            //  -   didOpen() is called before didChangeWatchedFiles() for new files
            //
            //  -   The text available in didOpen() and a possible immediately following
            //      didChange() is the most recent available. Even for new files, quickly
            //      made changes may be available in didOpen(), with the on-disk version
            //      of course being empty
            //
            //  -   For renames, didOpen is called for the new name before the old file
            //      is deleted in didChangeWatchedFiles. So, we'll let
            //      didChangeWatchedFiles() make the call to queueDiagnotics() for new
            //      files, in order to have a single call for the delete + add.
            //
            // We may be able to slightly improve the overall scheme by determining
            // exactly what is available in didOpen() vs. didChange(), when one or both
            // precede didChangeWatchedFiles(). This would help avoid an extra compile
            // when didChange() occurs before didChangeWatchedFiles().

            value documentId = toDocumentIdString(that.textDocument.uri);
            openDocuments.add(documentId);

            if (!inSourceDirectory(documentId)) {
                return;
            }

            if (exists existingText = textDocuments[documentId]) {
                // Update with the provided text and queue diagnistics if necessary.
                if (!corresponding(existingText.lines, that.textDocument.text.lines)) {
                    textDocuments[documentId] = that.textDocument.text;
                    queueDiagnotics(documentId);
                }
            }
            else {
                // New file. Save the text, but let the ensuing didChangeWatchedFiles()
                // call queueDiagnotics(). This helps avoid an extra, early, and
                // errant compile on file renames where didOpen() occurs for the new
                // file before the old file is deleted.
                textDocuments[documentId] = that.textDocument.text;
            }
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
        void didChangeWatchedFiles(DidChangeWatchedFilesParams that) {
            variable value changedFiles = [] of {String*};

            for (change in that.changes) {
                value documentId = toDocumentIdString(change.uri);
                if (!inSourceDirectory(documentId)) {
                    continue;
                }
                if (change.type == FileChangeType.deleted) {
                    value originalText = textDocuments.remove(documentId);
                    log.debug("deleted file '``documentId``'");
                    if (originalText exists) {
                        log.debug("queueing diagnsotics for deleted file \
                                   '``documentId``'");
                        // clear diagnostics immediately to prevent clicks in the GUI
                        // on diagnostics for files that don't exist
                        clearDiagnosticsForDocumentId(documentId);
                        changedFiles = changedFiles.follow(documentId);
                    }
                }
                else if (change.type == FileChangeType.created
                        || change.type == FileChangeType.changed) {

                    if (openDocuments.contains(documentId)) {
                        // If it's open, we already have the most recent contents
                        // (what's on disk may be stale). But, we do need to call
                        // queueDiagnostics for newly created files. See notes in
                        // didOpen().
                        //
                        // Note that there's *still* a chance for a redundant compile with
                        // didOpen() quickly followed by didChange(), and then finally
                        // this didChangeWatchedFiles() call.
                        log.debug("ignoring watched file change to already opened file \
                                   '``documentId``'");
                        changedFiles = changedFiles.follow(documentId);
                        continue;
                    }

                    // read or re-read from filesystem
                    value resource = parsePath(change.uri[7...]).resource;
                    switch (resource)
                    case (is File) {
                        value newText = readFile(resource);
                        value originalText = textDocuments.put(documentId, newText);
                        if (!eq(newText, originalText)) {
                            changedFiles = changedFiles.follow(documentId);
                        }
                    }
                    case (is Directory) {
                        // It's a directory named like 'x.ceylon'. Ignore.
                    }
                    case (is Nil) {
                        // A file can actually be changed and deleted in the same
                        // message! So don't treat this as an error
                        log.warn {
                            "unable to read watched file '``change.uri``'";
                        };
                    }
                    case (is Link) {
                        throw ReportableException {
                            "unable to read watched file '``change.uri``'";
                        };
                    }
                }
            }

            queueDiagnotics(*changedFiles);
        }

        shared actual
        CompletableFuture<List<out SymbolInformation>>? symbol(WorkspaceSymbolParams that)
            =>  null;
    };

    void clearDiagnosticsForDocumentId(String documentId) {
        value p = PublishDiagnosticsParamsImpl();
        p.uri = toUri(documentId);
        p.diagnostics = JavaList<DiagnosticImpl>([]);
        publishDiagnostics.accept(p);
    }

    void queueDiagnotics(String* documentIds) {
        typeCheckQueue.addAll(documentIds);
        launchCompiler();
    }

    void runAsync(Anything() run) {
        // TODO keep track of these, and shut them down if an exit or shutdown
        //      message is recieved
        value runArgument = run;
        CompletableFuture.runAsync(runnable {
            void run() {
                try {
                    runArgument();
                }
                catch (AssertionError | Exception t) {
                    onError(t.message, t);
                }
            }
        });
    }

    void launchCompiler() {
        if (typeCheckQueue.empty) {
            return;
        }

        // launch a compile task if one isn't running
        if (compiling.compareAndSet(false, true)) {
            log.debug("launching compiler");
            runAsync(() {
                try {
                    // TODO For files that are not part of a module (which means not
                    //      in a source directory, I guess), compile individually with
                    //      compileAndPublishDiagnostics? Maybe only if there is no
                    //      InitializeParams.rootPath? Perhaps parse, but don't
                    //      typecheck? Or do typecheck so completion, etc, works,
                    //      but don't report analysis errors?
                    //
                    //      If so, they should probably only be compiled when opened
                    //      and changed, with their diagnostics being cleared when
                    //      closed.

                    // TODO Until the above, we should ignore files that are not in
                    //      a source directory (or avoid having them added to the
                    //      queue in the first place.)
                    while (!typeCheckQueue.empty) {
                        value changedDocs = [*typeCheckQueue.clone()];
                        typeCheckQueue.clear();
                        value listings = textDocuments.clone();
                        compileModulesAndPublishDiagnostics(listings, changedDocs);
                    }
                }
                finally {
                    compiling.set(false);
                }
            });
        }
    }

    void compileModulesAndPublishDiagnostics(
            {<String->String>*} listings, [String*] changedDocs) {

        [String*] compiledDocumentIds;
        ListMultimap<String,DiagnosticImpl> allDiagnostics;
        // TODO Send error messages for all compile exceptions. Then, rethrow. Don't log
        //      the exception; message tracer will do this. If "ReportableException",
        //      don't show the exception type?
        //
        //      Actually, we should send error messages for all exceptions in
        //      the MessageTracer, no?

        try {
            value results
                =   compileModules(sourceDirectories, listings, changedDocs, this);

            compiledDocumentIds
                =   results[0];

            allDiagnostics
                =   ArrayListMultimap { *results[1] };
        }
        catch (Throwable e) {
            log.error("failed compile");

            value sb = StringBuilder();
            printStackTrace(e, sb.append);

            value exceptionType
                =   if (!e is ReportableException)
                    then let (cn = className(e))
                         cn[((cn.lastOccurrence('.')else-1)+1)...] + ": "
                    else "";

            showMessage.accept(newMessageParams {
                message = "Compilation failed: ``exceptionType``\
                           ``e.message.replace("\n", "; ")``\
                           \n\n``sb.string``";
                type = MessageType.error;
            });

            // wrap, so we don't re-report to the user
            throw ReportedException(e);
        }

        // FIXME We have to send diags for *all* files, since we need to clear
        // errors!!! Instead, we need to keep a list of files w/errors, to limit
        // the work here.
        for (documentId in compiledDocumentIds) {
            value diagnostics = allDiagnostics.get(documentId);
            value p = PublishDiagnosticsParamsImpl();
            p.uri = toUri(documentId);
            p.diagnostics = JavaList<DiagnosticImpl>(diagnostics);
            publishDiagnostics.accept(p);
        }
    }

    suppressWarnings("unusedDeclaration")
    void compileAndPublishDiagnostics(String documentId, String documentText) {
        value name = if (exists i = documentId.lastOccurrence('/'))
                     then documentId[i+1...]
                     else documentId;
        value diagnostics = compileFile(name, documentText);
        value p = PublishDiagnosticsParamsImpl();
        p.uri = toUri(documentId);
        p.diagnostics =JavaList(diagnostics);
        publishDiagnostics.accept(p);
    }

    String toDocumentIdString(String | Path uri) {
        // Note that the source directory is included in the documentId. For
        // example, 'source/com/example/file.ceylon', or if there is no root
        // directory, '/path/to/file.ceylon'.
        value path
            =   if (is Path uri)
                    then uri
                else if (uri.startsWith("file:///"))
                    // we need the right kind of Java nio path
                    then parsePath(uri[7...])
                else parsePath(uri);

        return if (exists rootDirectory = rootDirectory)
            then path.relativePath(rootDirectory.path).string
            else path.string;
    }

    //see(`function toDocumentIdString`)
    String toUri(String documentId)
        =>  if (exists rootDirectory = rootDirectory)
            then "file://" + rootDirectory.path.childPath(documentId)
                                .absolutePath.normalizedPath.string
            else "file://" + documentId;

    "Populate [[textDocuments]] with all source files found in all source directories.

     Files outside of source directories are ignored. These will likely need to be
     loaded in [[TextDocumentService.didOpen]] if we add support for them."
    void initializeDocuments(Directory rootDirectory) {
        for (relativeDirectory in sourceDirectories) {
            value sourceDirectory
                =   rootDirectory.path.childPath(relativeDirectory).resource;

            if (!is Directory sourceDirectory) {
                log.warn("cannot find '``relativeDirectory``' in the workspace \
                          '``rootDirectory.path``'");
            }

            // now, read all '*.ceylon' and '*.dart' files into memory!
            variable value count = 0;
            variable value startMillis = system.milliseconds;
            sourceDirectory.path.visit(object extends Visitor() {
                shared actual void file(File file) {
                    value extension
                        =   if (exists dot = file.name.lastOccurrence('.'))
                            then file.name[dot+1...]
                            else "";
                    if (extension in ["ceylon", "dart", "js", "java"]) {
                        value documentId = toDocumentIdString(file.path);
                        textDocuments.put(documentId, readFile(file));
                        count++;
                    }
                }
            });
            log.info("initialized ``count`` files in '``sourceDirectory``' \
                      in ``system.milliseconds - startMillis``ms");
        }
    }

    shared actual
    void onError(String? s, variable Throwable? throwable) {

        "Does this exception wrap an error that has already been reported to the user?"
        variable Boolean isReportedException = false;

        "Is the exception's text already formatted for the user?"
        variable Boolean isReportableException = false;

        while (true) {
            switch (t = throwable)
            case (is AssertionException) {
                throwable = t.cause;
            }
            case (is ReportedException) {
                isReportedException = true;
                throwable = t.cause;
            }
            case (is ReportableException) {
                isReportableException = true;
                break;
            }
            else {
                break;
            }
        }

        value unwrapped = throwable;

        if (exists unwrapped, !isReportedException) {
            // Send an error message to the client. If its anything but a
            // ReportableException, prefix with "ExceptionType: "
            try {
                value exceptionType
                    =   if (!isReportableException)
                        then let (cn = className(unwrapped))
                             cn[((cn.lastOccurrence('.')else-1)+1)...] + ": "
                        else "";

                showMessage.accept(newMessageParams {
                    message = "``exceptionType``\
                               ``unwrapped.message.replace("\n", "; ")``\
                               \n\n``unwrapped.string``";
                    type = MessageType.error;
                });
            }
            catch (AssertionError | Exception e) {
                // Oh well!
            }
        }

        log.error(()=>"(onError) ``s else ""``", throwable);
    }

    shared actual
    void onRead(Message? message, String? s) {
        value mm = message?.string else "<null>";
        value ss = s else "<null>";
        log.trace(()=>"(onRead) ``mm``, ``ss``");
    }

    shared actual
    void onWrite(Message? message, String? s) {
        value mm = message?.string else "<null>";
        value ss = s else "<null>";
        log.trace(()=>"(onWrite) ``mm``, ``ss``");
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
