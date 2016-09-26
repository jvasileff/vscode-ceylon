import ceylon.buffer.charset {
    utf8
}
import ceylon.collection {
    HashSet,
    HashMap
}
import ceylon.file {
    parsePath,
    Directory,
    Visitor,
    File,
    Nil,
    Link
}
import ceylon.interop.java {
    JavaList,
    CeylonMutableSet,
    JavaComparator,
    CeylonIterable,
    synchronize,
    javaString
}

import com.redhat.ceylon.common.config {
    DefaultToolOptions,
    CeylonConfig
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.model.typechecker.context {
    TypeCache
}
import com.redhat.ceylon.model.typechecker.model {
    Module
}
import com.vasileff.ceylon.dart.compiler {
    ReportableException
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
    Message,
    FileChangeType
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
    DiagnosticImpl,
    CompletionListImpl,
    CompletionItemImpl,
    MarkedStringImpl,
    HoverImpl
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
import java.lang {
    JBoolean=Boolean,
    Error
}
import java.util {
    List
}
import java.util.concurrent {
    CompletableFuture,
    ConcurrentSkipListSet
}
import java.util.concurrent.atomic {
    AtomicBoolean
}
import java.util.\ifunction {
    Consumer
}

class CeylonLanguageServer() satisfies LanguageServer & MessageTracer & LSContext {
    shared actual variable Set<Module> moduleCache = emptySet;

    shared actual late Consumer<PublishDiagnosticsParams> publishDiagnostics;
    shared actual late Consumer<MessageParams> logMessage;
    shared actual late Consumer<MessageParams> showMessage;
    shared actual late Consumer<ShowMessageRequestParams> showMessageRequest;
    shared actual late Directory? rootDirectory;
    shared actual variable JsonObject? settings = null;
    shared actual variable [String*] sourceDirectories = ["source/"];

    value openDocuments
        =   CeylonMutableSet(ConcurrentSkipListSet<String>(
                    JavaComparator(uncurry(String.compare))));

    compilingLevel1 = AtomicBoolean(false);
    compilingLevel2 = AtomicBoolean(false);

    documents = HashMap<String, String>();
    changedDocumentIds = HashSet<String>();
    phasedUnits = HashMap<String, [PhasedUnit*]>();

    level2QueuedRoots = HashSet<Module>();
    level2QueuedModuleNames = HashSet<String>();
    level2RefreshingModuleNames = HashSet<String>();
    cachedModuleNamesCompiledFromSource = HashSet<String>();

    LSContext context => this;

    function inSourceDirectory(String documentId)
        =>  sourceDirectories.any((d) => documentId.startsWith(d));

    shared actual
    CompletableFuture<InitializeResult> initialize(InitializeParams that) {
        log.info("initialize called");

        // TODO how exactly should TypeCaches be managed?
        TypeCache.setEnabledByDefault(true);

        if (exists rootPathString = that.rootPath) {
            log.info("rootPath is ``rootPathString``");
            // TODO make sure normalize is what we want. Don't resolve symlinks
            value rootPath = parsePath(rootPathString).absolutePath.normalizedPath;
            value rootDirectory = rootPath.resource;
            if (is Directory rootDirectory) {
                this.rootDirectory = rootDirectory;

                // Setup source directories. Note that initialize() is called before
                // didChangeConfiguraton(), so it will take much more work to make
                // source directories configurable
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
                                showError(message);
                                log.error(message);
                                return null;
                            }
                            return relativePath;
                        }).coalesced.sequence();

                log.info("configured source directories: ``sourceDirectories``");

                synchronize(context, () {
                    // read sourcefiles into memory
                    initializeDocuments(rootDirectory);
                    changedDocumentIds.addAll(documents.keys);
                });
                launchLevel1Compiler(this);
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
        capabilities.setHoverProvider(JBoolean(true));
        capabilities.completionProvider = CompletionOptionsImpl(JBoolean(false),
                JavaList([javaString(".")]));
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
            // TODO synchronize with compiles

            value documentId = toDocumentIdString(that.textDocument.uri);

            if (!inSourceDirectory(documentId)) {
                // Always send an empty completion list for non-source files
                value result = CompletionListImpl();
                result.items = JavaList<CompletionItemImpl>([]);
                return CompletableFuture.completedFuture<CompletionList>(result);
            }

            if (exists moduleName
                        =   moduleNameForDocumentId(
                                    allModuleNames, sourceDirectories, documentId),
                    nonempty units
                        =   phasedUnits[moduleName]) {

                value completer
                    =   Autocompleter {
                            documentId;
                            that.position.line + 1;
                            that.position.character;
                            units;
                };

                if (!completer.completions.empty) {
                    value builder = CompletionListBuilder();
                    for (completion in completer.completions) {
                        builder.item(CompletionItemBuilder()
                            .insertText(renderCompletionInsertText(completion))
                            .label(renderCompletionLabel(completion))
                            .detail(renderCompletionDetail(completion))
                            .documentation(renderCompletionDocumentation(completion))
                            // TODO set kind
                            //.kind(CompletionItemKind.method)
                            .build());
                    }
                    return CompletableFuture.completedFuture<CompletionList>(
                            builder.build());
                }
            }

            // nothing found, but mark incomplete since it may be because we haven't
            // finished a compile
            return CompletableFuture.completedFuture<CompletionList>(
                CompletionListBuilder().incomplete(true).build());
        }

        shared actual
        CompletableFuture<List<out Location>>? definition(TextDocumentPositionParams that)
            =>  null;

        shared actual
        void didChange(DidChangeTextDocumentParams that) {
            if (!that.textDocument.uri.startsWith("file:")) {
                return;
            }

            value documentId = toDocumentIdString(that.textDocument.uri);

            if (!inSourceDirectory(documentId)) {
                return;
            }

            synchronize(context, () {
                value existingText = documents[documentId];
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
                documents[documentId] = newText;
                changedDocumentIds.add(documentId);
            });
            launchLevel1Compiler(context);
        }

        shared actual
        void didClose(DidCloseTextDocumentParams that) {
            if (!that.textDocument.uri.startsWith("file:")) {
                return;
            }

            value documentId = toDocumentIdString(that.textDocument.uri);
            openDocuments.remove(documentId);
        }

        shared actual
        void didOpen(DidOpenTextDocumentParams that) {
            if (!that.textDocument.uri.startsWith("file:")) {
                return;
            }

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

            synchronize(context, () {
                if (exists existingText = documents[documentId]) {
                    // Update with the provided text and queue diagnistics if necessary.
                    if (!corresponding(existingText.lines, that.textDocument.text.lines)) {
                        documents[documentId] = that.textDocument.text;
                        changedDocumentIds.add(documentId);
                    }
                }
                else {
                    // New file. Save the text, but let the ensuing didChangeWatchedFiles()
                    // call queueDiagnotics(). This helps avoid an extra, early, and
                    // errant compile on file renames where didOpen() occurs for the new
                    // file before the old file is deleted.
                    documents[documentId] = that.textDocument.text;
                    // FIXME adding the line below, because what's document above doesn't
                    //       work well for open file saves
                    // FIXME 2 why "errant compile" in the note above!? Oh, actually, it was
                    //          prob that for renames we would wind up with bogus duplicate
                    //          declaration errors while we temp. have both files.... So, ugh.
                    changedDocumentIds.add(documentId);
                }
            });
            launchLevel1Compiler(outer);
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
        CompletableFuture<Hover>? hover(TextDocumentPositionParams that) {
            // TODO synchronize with compiles

            value documentId = toDocumentIdString(that.textDocument.uri);

            if (!inSourceDirectory(documentId)) {
                // Always send an empty Hover for non-source files
                return CompletableFuture.completedFuture<Hover>(
                    HoverImpl(JavaList<MarkedStringImpl>([]), null));
            }

            if (exists moduleName
                        =   moduleNameForDocumentId(
                                allModuleNames, sourceDirectories, documentId),

                    nonempty units
                        =   phasedUnits[moduleName],

                    exists declaration
                        =   findDeclaration {
                                documentId = documentId;
                                row = that.position.line + 1;
                                col = that.position.character;
                                phasedUnits = units;
                            }) {

                value docs = getDeclarationInfo(declaration).string;
                value hover = HoverBuilder();
                hover.content(MarkedStringImpl(MarkedStringImpl.plainString, docs));
                return CompletableFuture.completedFuture<Hover>(hover.build());
            }

            // nothing found. Send an empty Hover
            return CompletableFuture.completedFuture<Hover>(
                HoverImpl(JavaList<MarkedStringImpl>([]), null));
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
            settings
                =   if (is JsonObject obj = forceWrapJavaJson(that.settings))
                    then obj else null;

            // update logging level
            if (exists p = ceylonSettings?.getStringOrNull("serverLogPriority")) {
                setLogPriority(p);
            }
        }

        shared actual
        void didChangeWatchedFiles(DidChangeWatchedFilesParams that) {

            synchronize(context, () {
            variable value changedFiles = [] of {String*};

            for (change in that.changes) {
                if (!change.uri.startsWith("file:")) {
                    continue;
                }

                value documentId = toDocumentIdString(change.uri);
                if (!inSourceDirectory(documentId)) {
                    continue;
                }
                if (change.type == FileChangeType.deleted) {
                    value originalText = documents.remove(documentId);
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

                        // FIXME well... this happens on saves of open files too.
                        //       so we can't queue diagnostics here, redundantly.
                        // FIXME review the fix of just doing the alert in didOpen. Look
                        //       again and see if didChange() can help with the new file
                        //       issue.
                        log.debug("ignoring FileChangeType.changed message for already \
                                   opened file '``documentId``'");
                        // FIXME removing: changedFiles = changedFiles.follow(documentId);
                        continue;
                    }

                    // read or re-read from filesystem
                    value resource = parsePath(change.uri[7...]).resource;
                    switch (resource)
                    case (is File) {
                        value newText = readFile(resource);
                        value originalText = documents.put(documentId, newText);
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
            changedDocumentIds.addAll(changedFiles);
            });
            launchLevel1Compiler(context);
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

    "Populate [[documents]] with all source files found in all source directories.

     Files outside of source directories are ignored. These will likely need to be
     loaded in [[TextDocumentService.didOpen]] if we add support for them."
    void initializeDocuments(Directory rootDirectory) => synchronize(context, () {
        for (relativeDirectory in sourceDirectories) {
            value sourceDirectory
                =   rootDirectory.path.childPath(relativeDirectory).resource;

            if (!is Directory sourceDirectory) {
                value message = "cannot find the configured source directory \
                                 '``relativeDirectory``' in the workspace \
                                 '``rootDirectory.path``'";
                log.warn(message);
                showWarning(message);
                continue;
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
                        documents.put(documentId, readFile(file));
                        count++;
                    }
                }
            });
            log.info("initialized ``count`` files in '``sourceDirectory``' \
                      in ``system.milliseconds - startMillis``ms");
        }
    });

    shared actual
    void onError(String? s, variable Throwable? throwable) {

        "Does this exception wrap an error that has already been reported to the user?"
        variable Boolean isReportedException = false;

        "Is the exception's text already formatted for the user?"
        variable Boolean isReportableException = false;

        while (true) {
            switch (t = throwable)
            case (is WrappedError) {
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
            // Send an error message to the client. If it's anything but a
            // ReportableException, prefix with "ExceptionType: "
            //
            // If it's a non AssertionError Error, prefix with "Fatal Error: "
            try {
                value prefix = StringBuilder();
                if (!isReportableException) {
                    if (unwrapped is Error && !unwrapped is AssertionError) {
                        prefix.append("Fatal Error: ");
                    }
                    value cn = className(unwrapped);
                    prefix.append(
                        cn[((cn.lastOccurrence('.')else-1)+1)...] + ": ");
                }
                showError("``prefix``\
                           ``unwrapped.message.replace("\n", "; ")``\
                           \n\n``unwrapped.string``");
            }
            catch (AssertionError | Exception e) {
                // Oh well!
            }
        }

        log.error(()=>"(onError) ``s else ""``", throwable);

        if (exists unwrapped, unwrapped is Error && !unwrapped is AssertionError) {
            // If from the main thread, this shuts down the server. We should probably
            // do the same from background jobs too, although typechecker SOEs are
            // really a problem.
            throw unwrapped;
        }
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
