import ceylon.buffer.charset {
    utf8
}
import ceylon.interop.java {
    createJavaByteArray
}

import com.redhat.ceylon.compiler.typechecker.analyzer {
    UsageWarning
}
import com.redhat.ceylon.compiler.typechecker.io {
    VirtualFile
}
import com.redhat.ceylon.compiler.typechecker.parser {
    RecognitionError
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Message,
    AnalysisMessage
}
import com.vasileff.ceylon.dart.compiler {
    javaList,
    compileDartSP
}
import com.vasileff.ceylon.structures {
    ArrayListMultimap,
    HashMultimap
}
import com.vasileff.ceylon.vscode.internal {
    newDiagnostic,
    log
}

import io.typefox.lsapi {
    DiagnosticSeverity
}
import io.typefox.lsapi.impl {
    DiagnosticImpl
}

import java.io {
    ByteArrayInputStream,
    InputStream
}

[<String->DiagnosticImpl>*] compileModules({<String -> String>*} listings1 = {}) {
    // TODO support source directories other than "source/"!
    value listings = listings1.map((path->text) {
        // remove leading "source/" from listings.
        assert (exists slash = path.firstOccurrence('/'));
        return path[slash+1...]->text;
    });

    "The full path, parent directory, and file."
    function pathParts(String path) {
        value trimmed = path.trim('/'.equals);
        value components = trimmed.split('/'.equals).sequence();

        "nonempty paths will have at least one path segment."
        assert (nonempty components);

        return ["/".join(components.exceptLast),
                "/".join(components),
                components.last];
    }

    "The path, and all parent directories."
    function directoryAndParents(String path)
        =>  let (trimmed = path.trim('/'.equals),
                segments = trimmed.split('/'.equals).sequence())
            { for (i in 1:segments.size) "/".join(segments.take(i)) };

    value files
        =   ArrayListMultimap<String, VirtualFile> {
                *listings.map((listing)
                    =>  let ([d, p, n] = pathParts(listing.key))
                        d -> object satisfies VirtualFile {
                            children = javaList<VirtualFile> {};

                            path = p;

                            name = n;

                            folder = false;

                            \iexists() => true;

                            shared actual
                            String? getRelativePath(VirtualFile ancestor)
                                =>  if (path == ancestor.path)
                                        then ""
                                    else if (ancestor.path == "")
                                        then path
                                    else if (path.startsWith("``ancestor.path``/"))
                                        then path[ancestor.path.size+1...]
                                    else null;

                            inputStream
                                =>  ByteArrayInputStream(createJavaByteArray(
                                        utf8.encode(listing.item)));

                            compareTo(VirtualFile other)
                                =>  switch (path.compare(other.path))
                                    case (smaller) -1
                                    case (larger) 1
                                    case (equal) 0;
                        })
            };

    log.debug("files to compile: ``files``");

    value directories
        =   HashMultimap<String, String> {
                *files.keys.flatMap(directoryAndParents).map((directory)
                    =>  let ([d, p, n] = pathParts(directory))
                        d -> p)
            };

    class DirectoryVirtualFile satisfies VirtualFile {
        shared actual String path;

        shared new (String path) {
            this.path = path.trimLeading('/'.equals);
        }

        name = pathParts(path)[2];

        folder = true;

        \iexists() => true;

        shared actual
        String? getRelativePath(VirtualFile ancestor)
            =>  if (path == ancestor.path)
                    then ""
                else if (ancestor.path == "")
                    then path
                else if (path.startsWith("``ancestor.path``/"))
                    then path[ancestor.path.size+1...]
                else null;

        children
            =   javaList<VirtualFile> {
                    expand {
                        directories.get(path).map(DirectoryVirtualFile),
                        files.get(path)
                    };
                };

        compareTo(VirtualFile other)
            =>  switch (path.compare(other.path))
                case (smaller) -1
                case (larger) 1
                case (equal) 0;

        shared actual
        InputStream inputStream {
            throw AssertionError("Directories don't have input streams.");
        }
    }

    value [cuList, status, messages] = compileDartSP {
        virtualFiles = [DirectoryVirtualFile("")];
    };

    // TODO support source directories other than "source/"!
    return messages
        .filter((_->m)
            =>  if (is UsageWarning m)
                then !m.suppressed
                else true)
        // TODO should there be a limit?
        //.take(500)
        .collect((node->message)
            =>  "source/" + node.unit.fullPath -> newDiagnostic {
                    message = message.message;
                    range = rangeForMessage(message);
                    severity = message.warning
                        then DiagnosticSeverity.warning
                        else DiagnosticSeverity.error;
                });
}
