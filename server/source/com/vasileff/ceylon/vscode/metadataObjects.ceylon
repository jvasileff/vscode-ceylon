import ceylon.markdown.core {
    parse,
    Paragraph
}

import com.vasileff.ceylon.vscode {
    DeclarationKind {
        constructor,
        classKind,
        interfaceKind,
        typeParameter,
        typeAlias,
        valueKind,
        setter,
        functionKind,
        unknown
    }
}

class DeclarationInfo(
        shared SignatureInfo signatureInfo,
        shared String? packageContainer,
        shared String? classOrInterfaceContainer,
        "If this is a class, it's extended type"
        shared String? extendedType,
        "If this is a class, interface, or type parameter, it's satisfied types."
        shared [String*] satisfiedTypes,
        "Documentation in markdown format, or null if there are no docs"
        shared DocInfo? docInfo) {

    shared void write(Anything(String) write) {
        writeSignatureMarkdown(write);
        write("\n");
        writeDocMarkdown(write);
    }

    shared void writeSignatureMarkdown(Anything(String) write) {
        // signature
        write("**`");
        signatureInfo.write(write);
        write("`**");
    }

    shared void writeDocMarkdown(Anything(String) write) {
        value bullet = "-";

        if (exists docInfo) {
            docInfo.write(write);
            write("\n");
        }
        if (exists packageContainer) {
            write("\n");
            write("``bullet`` Member of: ```packageContainer```");
            write("\n");
        }
        else if (exists classOrInterfaceContainer) {
            write("\n");
            write("``bullet`` Member of: ```classOrInterfaceContainer```");
            write("\n");
        }
        if (exists extendedType) {
            write("\n");
            write("``bullet`` Extends: ```extendedType```");
            write("\n");
        }
        if (nonempty satisfiedTypes) {
            write("\n");
            write("``bullet`` Satisfies: ```" & ".join(satisfiedTypes)```");
            write("\n");
        }

        // TODO "parameterInfo" see, returns, throws, accepts
    }

    shared String docMarkdownString {
        value sb = StringBuilder();
        writeDocMarkdown(sb.append);
        return sb.string;
    }

    shared actual String string {
        value sb = StringBuilder();
        write(sb.append);
        return sb.string;
    }
}

class DocInfo(
        "Documentation in markdown format"
        shared String doc,
        "If the doc was inherited, the refined declaration providing the doc"
        shared String? docSource) {

    shared void write(Anything(String) write) {
        value document = parse(doc);
        value firstParagraph = document.children.narrow<Paragraph>().first;
        if (exists firstParagraph) {
            renderPlainText(firstParagraph, write);
        }
        else {
            write(doc);
        }
        // TODO "specified by refined declaration docSource"
    }

    shared actual String string {
        value sb = StringBuilder();
        write(sb.append);
        return sb.string;
    }
}

class SignatureInfo(
        "Is this a void function?"
        shared Boolean isVoid,
        "The type, if this is a TypedDeclaration"
        shared String? type,
        shared DeclarationKind kind,
        shared String name,
        shared Boolean isAnnotation,
        shared [String*] typeParameters,
        shared [ParameterListInfo*] parameterLists) {

    shared void write(Anything(String) write) {
        switch (kind)
        case (constructor | classKind | interfaceKind | typeParameter
                | typeAlias) {
            write(kind.keyword);
            write(" ");
        }
        else if (isVoid) {
            write("void ");
        }
        else if (exists type) {
            write(type);
            write(" ");
        }
        write(name);
        if (nonempty typeParameters) {
            write("<");
            write(", ".join(typeParameters));
            write(">");
        }
        parameterLists.each((pl) => pl.write(write));
    }

    shared actual String string {
        value sb = StringBuilder();
        write(sb.append);
        return sb.string;
    }
}

class DeclarationKind
        of constructor | classKind | interfaceKind | typeParameter | typeAlias
            | valueKind | setter | functionKind | unknown {

    shared String keyword;

    shared new constructor {
        this.keyword = "new";
    }
    shared new classKind {
        this.keyword = "class";
    }
    shared new interfaceKind {
        this.keyword = "interface";
    }
    shared new typeParameter {
        this.keyword = "given";
    }
    shared new typeAlias {
        this.keyword = "alias";
    }
    shared new valueKind {
        this.keyword = "value";
    }
    shared new setter {
        this.keyword = "assign";
    }
    shared new functionKind {
        this.keyword = "function";
    }
    shared new unknown {
        this.keyword = "unknown";
    }
}

class ParameterListInfo(
        shared [ParameterInfo*] parameters) {

    shared void write(Anything(String) write) {
        write("(");
        variable value first = true;
        for (parameter in parameters) {
            if (!first) {
                write(", ");
            }
            first = false;
            parameter.write(write);
        }
        write(")");
    }

    shared actual String string {
        value sb = StringBuilder();
        write(sb.append);
        return sb.string;
    }
}

class ParameterInfo(
        shared Boolean isVoid,
        shared String? type,
        "If sequenced, then '+' or '*'"
        shared Character? sequenced,
        shared String name) {

    shared void write(Anything(String) write) {
        if (isVoid) {
            write("void ");
        }
        else if (exists type) {
            write(type);
            if (exists sequenced) {
                write(sequenced.string);
            }
            write(" ");
        }
        write(name);
    }

    shared actual String string {
        value sb = StringBuilder();
        write(sb.append);
        return sb.string;
    }
}
