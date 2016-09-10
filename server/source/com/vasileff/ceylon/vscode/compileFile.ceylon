import io.typefox.lsapi {
    DiagnosticSeverity
}
import java.io {
    ByteArrayInputStream
}
import io.typefox.lsapi.impl {
    DiagnosticImpl
}
import ceylon.buffer.charset {
    utf8
}
import com.vasileff.ceylon.dart.compiler {
    compileDartSP,
    javaList
}
import ceylon.interop.java {
    createJavaByteArray
}
import com.redhat.ceylon.compiler.typechecker.io {
    VirtualFile
}
import com.vasileff.ceylon.vscode.internal {
    newDiagnostic
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Message
}
import com.redhat.ceylon.compiler.typechecker.analyzer {
    UsageWarning
}

[DiagnosticImpl*] compileFile(String name, String textContent) {

    value outerName = name;

    value virtualFile
        =   object satisfies VirtualFile {
                children => javaList<VirtualFile> {};
                name => outerName;
                path => name;
                folder => false;
                \iexists() => true;

                shared actual
                String? getRelativePath(VirtualFile ancestor)
                    =>  if (path == ancestor.path)
                            then ""
                        else if (path.startsWith("``ancestor.path``/"))
                            then path[ancestor.path.size+1...]
                        else null;

                inputStream
                    =>  ByteArrayInputStream(createJavaByteArray(
                            utf8.encode(textContent)));

                compareTo(VirtualFile other)
                    =>  switch (path.compare(other.path))
                        case (smaller) -1
                        case (larger) 1
                        case (equal) 0;
            };

    value [cuList, status, messages] = compileDartSP {
        virtualFiles = [virtualFile];
    };

    return messages
        .filter((m)
            =>  if (is UsageWarning m)
                then !m.suppressed
                else true)
        .take(500).collect((message)
            =>  newDiagnostic {
                    message = message.message;
                    range = rangeForMessage(message);
                    severity = message.warning
                        then DiagnosticSeverity.warning
                        else DiagnosticSeverity.error;
                });
}
