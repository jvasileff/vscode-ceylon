native ("jvm")
module com.vasileff.ceylon.vscode "0.0.1" {
    shared import java.base "8";
    shared import ceylon.file "1.3.0";
    shared import ceylon.buffer "1.3.0";
    shared import ceylon.logging "1.3.0";
    shared import ceylon.collection "1.3.0";
    shared import ceylon.interop.java "1.3.0";
    shared import com.redhat.ceylon.cli "1.3.0";
    shared import com.redhat.ceylon.common "1.3.0";
    shared import com.redhat.ceylon.typechecker "1.3.0";

    shared import com.vasileff.ceylon.structures "1.0.0";
    shared import com.vasileff.ceylon.dart.compiler "1.3.0-DP3";

    // ceylon.markdown.core is not in Herd
    shared import ceylon.markdown.core "1.0.0-vscode";

    shared import maven:"io.typefox.lsapi:io.typefox.lsapi" "0.3.0";
    shared import maven:"io.typefox.lsapi:io.typefox.lsapi.services" "0.3.0";
    shared import maven:"io.typefox.lsapi:io.typefox.lsapi.annotations" "0.3.0";

    // shouldn't be necessary, but is:
    shared import maven:"org.eclipse.xtend:org.eclipse.xtend.lib" "2.10.0";
    shared import maven:"org.eclipse.xtext:org.eclipse.xtext.xbase.lib" "2.10.0";
}
