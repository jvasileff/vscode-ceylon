native ("jvm")
module com.vasileff.ceylon.vscode "0.1.0" {
    shared import java.base "8";
    shared import ceylon.file "1.3.2";
    shared import ceylon.buffer "1.3.2";
    shared import ceylon.logging "1.3.2";
    shared import ceylon.collection "1.3.2";
    shared import ceylon.interop.java "1.3.2";
    import ceylon.regex "1.3.2";

    shared import com.redhat.ceylon.cli "1.3.2";
    shared import com.redhat.ceylon.common "1.3.2";
    shared import com.redhat.ceylon.typechecker "1.3.2";

    import com.redhat.ceylon.compiler.js "1.3.2";

    shared import com.vasileff.ceylon.structures "1.1.1";
    shared import com.vasileff.ceylon.dart.compiler "1.3.2-DP5-SNAPSHOT";

    shared import maven:"org.eclipse.lsp4j:org.eclipse.lsp4j" "0.1.1";
    shared import maven:"org.eclipse.lsp4j:org.eclipse.lsp4j.jsonrpc" "0.1.1";
}
