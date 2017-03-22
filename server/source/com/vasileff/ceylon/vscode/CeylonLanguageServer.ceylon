import ceylon.buffer.charset {
    utf8
}
import ceylon.collection {
    HashSet,
    HashMap,
    ArrayList
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
import com.vasileff.ceylon.structures {
    ArrayListMultimap
}
import com.vasileff.ceylon.vscode.idecommon {
    FindDeclarationNodeVisitor,
    getIdentifyingNode,
    FindReferencesVisitor
}

import java.io {
    JFile=File
}
import java.lang {
    JBoolean=Boolean
}
import java.util {
    List
}
import java.util.concurrent {
    CompletableFuture,
    ConcurrentSkipListSet,
    CompletionException,
    CancellationException
}
import java.util.concurrent.atomic {
    AtomicBoolean
}
import java.util.\ifunction {
    Function,
    Supplier
}

import org.eclipse.lsp4j {
    CodeActionParams,
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
    FileChangeType,
    DocumentHighlightKind,
    ServerCapabilities,
    CompletionOptions,
    Diagnostic
}
import org.eclipse.lsp4j.services {
    LanguageClientAware,
    LanguageClient,
    LanguageServer,
    TextDocumentService,
    WorkspaceService
}

class CeylonLanguageServer()
        satisfies LanguageServer
                & LanguageClientAware
                & ErrorListener
                & CeylonLanguageServerContext {

    shared actual variable Set<Module> moduleCache = emptySet;

    shared actual late LanguageClient languageClient;
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
    documentIdsWithDiagnostics = HashSet<String>();

    phasedUnits = HashMap<String, [PhasedUnit*]>();
    compiledDocumentIdFutures = ArrayListMultimap
            <String, CompletableFuture<[PhasedUnit=]>>();

    shared actual variable Set<String> level1CompilingChangedDocumentIds = emptySet;
    shared actual variable Set<String> level2CompilingChangedDocumentIds = emptySet;

    level2QueuedRoots = HashSet<Module>();
    level2QueuedModuleNames = HashSet<String>();
    level2RefreshingModuleNames = HashSet<String>();
    cachedModuleNamesCompiledFromSource = HashSet<String>();

    CeylonLanguageServerContext context => this;

    shared actual
    void connect(LanguageClient languageClient)
        =>  this.languageClient = languageClient;

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

        value result = InitializeResult();
        value capabilities = ServerCapabilities();

        capabilities.textDocumentSync = TextDocumentSyncKind.incremental;
        capabilities.hoverProvider = JBoolean(true);
        capabilities.completionProvider = CompletionOptions(
                JBoolean(false), JavaList([javaString(".")]));
        capabilities.definitionProvider = JBoolean(true);
        capabilities.documentHighlightProvider = JBoolean(true);
        result.capabilities = capabilities;

        return CompletableFuture.completedFuture<InitializeResult>(result);
    }

    shared actual
    suppressWarnings("expressionTypeNothing")
    void exit() {
        log.info("exit called");
        // TODO there has to be a better way...
        process.exit(0);
    }

    shared actual
    CompletableFuture<Object> shutdown() {
        log.info("shutdown called");
        // for whatever reason, using 'object {}' results in an invalid JSON message.
        return CompletableFuture.completedFuture<Object>(JavaUtil.newJavaObject());
    }

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

            if (!exists documentId) {
                return CompletableFuture.completedFuture(CompletionList());
            }

            return
            unitForDocumentId(documentId).thenApplyAsync<CompletionList>(object
                    satisfies Function<[PhasedUnit=], CompletionList> {
                shared actual CompletionList apply([PhasedUnit=] unit) {
                    value completionList = CompletionList();
                    if (!nonempty unit) {
                        return completionList;
                    }
                    value completer
                        =   Autocompleter {
                                documentId;
                                that.position.line + 1;
                                that.position.character;
                                unit.first;
                    };
                    for (completion in completer.completions) {
                        value item = CompletionItem();
                        item.insertText = renderCompletionInsertText(completion);
                        item.label = renderCompletionLabel(completion);
                        item.detail = renderCompletionDetail(completion);
                        item.documentation = renderCompletionDocumentation(completion);
                        item.kind = completion.kind;

                        completionList.items.add(item);
                    }
                    if (completer.completions.empty) {
                        completionList.setIsIncomplete(true);
                    }
                    return completionList;
                }
            });
        }

        shared actual
        CompletableFuture<List<out Location>> definition
                (TextDocumentPositionParams that) {

            // TODO synchronize this?

            // can we determine the declaration?
            if (exists documentId = toDocumentIdString(that.textDocument.uri),
                isSourceFile(documentId),
                exists unit = findUnitForDocumentId(documentId),
                exists declaration
                        =   findDeclaration {
                                documentId = documentId;
                                row = that.position.line + 1;
                                col = that.position.character;
                                phasedUnit = unit;
                            }) {

                // is the declaration in the workspace, and can we find the PhasedUnit?
                value declarationDocumentId = declaration.unit.fullPath else null;
                if (exists declarationDocumentId,
                    isSourceFile(declarationDocumentId),
                    exists declarationUnit
                        =   findUnitForDocumentId(declarationDocumentId)) {

                    // find the identifying node and we're done
                    value fdnv = FindDeclarationNodeVisitor(declaration);
                    declarationUnit.compilationUnit.visit(fdnv);
                    if (exists node = fdnv.declarationNode,
                        exists idNode = getIdentifyingNode(node)) {
                        value range
                            =   newRange {
                                    newPosition {
                                        line = idNode.token.line - 1;
                                        character = idNode.token.charPositionInLine;
                                    };
                                    newPosition {
                                        line = idNode.endToken.line - 1;
                                        character = idNode.endToken.charPositionInLine
                                            + idNode.endToken.text.size;
                                    };
                                };
                        return CompletableFuture.completedFuture<List<out Location>>(
                            JavaList {
                                [Location(toUri(declarationDocumentId), range)];
                            });
                    }
                }
            }

            // nothing found. Send an empty list
            return CompletableFuture.completedFuture<List<out Location>>(JavaList([]));
        }

        shared actual
        void didChange(DidChangeTextDocumentParams that) {
            if (!that.textDocument.uri.startsWith("file:")) {
                return;
            }

            value documentId = toDocumentIdString(that.textDocument.uri);

            if (!isSourceFile(documentId)) {
                return;
            }
            assert (exists documentId);

            synchronize(context, () {
                value existingText = documents[documentId];
                if (!exists existingText) {
                    throw ReportableException("did not find changed document \
                                               '``documentId``'");
                }
                variable value newText = existingText;
                for (change in that.contentChanges) {
                    newText = replaceRange(newText, change.range, change.text);
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

            if (exists documentId = toDocumentIdString(that.textDocument.uri)) {
                openDocuments.remove(documentId);
            }
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
            if (!exists documentId) {
                return;
            }

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
        CompletableFuture<List<out DocumentHighlight>>? documentHighlight
                (TextDocumentPositionParams that) {

            value documentId = toDocumentIdString(that.textDocument.uri);

            // TODO should we wait for compile with unitForDocumentId(documentId)?

            if (exists documentId,
                isSourceFile(documentId),
                exists unit
                        =   findUnitForDocumentId(documentId),
                exists declaration
                        =   findDeclaration {
                                documentId = documentId;
                                row = that.position.line + 1;
                                col = that.position.character;
                                phasedUnit = unit;
                            }) {

                return CompletableFuture.supplyAsync(object
                        satisfies Supplier<List<out DocumentHighlight>> {
                    shared actual List<out DocumentHighlight> get() {

                        value frv = FindReferencesVisitor(declaration);

                        // TODO distiguish read vs write occurences. The IntelliJ
                        //      plugin seems to be able to do this. Or, the
                        //      FindAssignmentsVisitor can probably be adapted.

                        // FIXME declarations assigned to in the same scope are not
                        //      being highlighted, while the last assignment is being
                        //      highlighted *in full* as the declaration.
                        //          variable Integer x1 = 0;
                        //          x1 = 1;
                        //          x1 = 2;

                        value highlights = ArrayList<DocumentHighlight>();
                        unit.compilationUnit.visit(frv);
                        for (node in frv.referenceNodes) {
                            if (exists range = rangeForNode(node)) {
                                value documentHighlight = DocumentHighlight();
                                documentHighlight.range = range;
                                documentHighlight.kind = DocumentHighlightKind.text;
                                highlights.add(documentHighlight);
                            }
                        }

                        value fdnv = FindDeclarationNodeVisitor(frv.declaration);
                        unit.compilationUnit.visit(fdnv);
                        if (exists declarationNode = fdnv.declarationNode,
                                exists node = getIdentifyingNode(declarationNode),
                                exists range = rangeForNode(node)) {
                            value documentHighlight = DocumentHighlight();
                            documentHighlight.range = range;
                            documentHighlight.kind = DocumentHighlightKind.text;
                            highlights.add(documentHighlight);
                        }

                        return JavaList(highlights);
                    }
                });
            }

            return CompletableFuture.completedFuture<List<out DocumentHighlight>>(
                    JavaList<DocumentHighlight>([]));
        }

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

            if (!isSourceFile(documentId)) {
                // Always send an empty Hover for non-source files
                return CompletableFuture.completedFuture<Hover>(Hover());
            }
            assert (exists documentId);

            if (exists unit
                        =   findUnitForDocumentId(documentId),
                exists declaration
                        =   findDeclaration {
                                documentId = documentId;
                                row = that.position.line + 1;
                                col = that.position.character;
                                phasedUnit = unit;
                            }) {

                value declarationInfo = getDeclarationInfo(declaration);
                value hover = Hover();
                hover.contents.add(javaString {
                    "\`\`\`\n``declarationInfo.signatureInfo.string``\n\`\`\`\n";
                });
                hover.contents.add(javaString(declarationInfo.docMarkdownString));
                return CompletableFuture.completedFuture<Hover>(hover);
            }

            // nothing found. Send an empty Hover
            return CompletableFuture.completedFuture<Hover>(Hover());
        }

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
    WorkspaceService workspaceService => object satisfies WorkspaceService {
        shared actual
        void didChangeConfiguration(DidChangeConfigurationParams that) {
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
                if (!isSourceFile(documentId)) {
                    continue;
                }
                assert (exists documentId);
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
        value p = PublishDiagnosticsParams();
        p.uri = toUri(documentId);
        p.diagnostics = JavaList<Diagnostic>([]);
        languageClient.publishDiagnostics(p);
    }

    suppressWarnings("unusedDeclaration")
    void compileAndPublishDiagnostics(String documentId, String documentText) {
        value name = if (exists i = documentId.lastOccurrence('/'))
                     then documentId[i+1...]
                     else documentId;
        value diagnostics = compileFile(name, documentText);
        value p = PublishDiagnosticsParams();
        p.uri = toUri(documentId);
        p.diagnostics =JavaList(diagnostics);
        languageClient.publishDiagnostics(p);
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
                        if (exists documentId = toDocumentIdString(file.path)) {
                            documents.put(documentId, readFile(file));
                            count++;
                        }
                    }
                }
            });
            log.info("initialized ``count`` files in '``sourceDirectory``' \
                      in ``system.milliseconds - startMillis``ms");
        }
    });

    shared actual
    void onError(variable Throwable? throwable) {
        if (throwable is CancellationException) {
            // ignore cancellations
            return;
        }

        "Does this exception wrap an error that has already been reported to the user?"
        variable Boolean isReportedException = false;

        "Is the exception's text already formatted for the user?"
        variable Boolean isReportableException = false;

        while (true) {
            switch (t = throwable)
            case (is CompletionException) {
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

        if (!exists unwrapped) {
            return;
        }

        if (!isReportedException) {
            // Send an error message to the client. If it's anything but a
            // ReportableException, prefix with "ExceptionType: "
            //
            // If it's a non AssertionError Error, prefix with "Fatal Error: "
            value prefix = StringBuilder();
            if (!isReportableException) {
                value cn = className(unwrapped);
                prefix.append(cn[((cn.lastOccurrence('.')else-1)+1)...] + ": ");
            }
            showError("``prefix``\
                       ``unwrapped.message.replace("\n", "; ")``\
                       \n\n``unwrapped.string``");
        }

        log.error(unwrapped.message, unwrapped);
    }
}

[Byte*] readBytes(File.Reader reader, Integer count) {
    try {
        return reader.readBytes(count);
    }
    catch (AssertionError e) {
        // workaround https://github.com/ceylon/ceylon-sdk/issues/653
        if (e.message == "end must be positive") {
            return [];
        }
        throw e;
    }
}

String readFile(File file) {
    // we can't use ceylon.file::lines() because it doesn't retain the trailing
    // newline, if one exists.
    try (reader = file.Reader()) {
        value decoder = utf8.cumulativeDecoder();
        while (nonempty bytes = readBytes(reader, 100)) {
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
