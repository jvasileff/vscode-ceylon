native ("jvm")
module com.vasileff.ceylon.vscode "0.1.0" {
    shared import java.base "8";
    shared import ceylon.file "1.3.1";
    shared import ceylon.buffer "1.3.1";
    shared import ceylon.logging "1.3.1";
    shared import ceylon.collection "1.3.1";
    shared import ceylon.interop.java "1.3.1";

    shared import com.redhat.ceylon.cli "1.3.1";
    shared import com.redhat.ceylon.common "1.3.1";
    shared import com.redhat.ceylon.typechecker "1.3.1";

    import com.redhat.ceylon.compiler.js "1.3.1";

    shared import com.vasileff.ceylon.structures "1.1.0";
    shared import com.vasileff.ceylon.dart.compiler "1.3.1-DP5-SNAPSHOT";

    // ceylon.markdown.core is not in Herd
    shared import ceylon.markdown.core "1.0.1-vscode";

    shared import maven:"org.eclipse.lsp4j:org.eclipse.lsp4j" "0.1.1";
    shared import maven:"org.eclipse.lsp4j:org.eclipse.lsp4j.jsonrpc" "0.1.1";
}
