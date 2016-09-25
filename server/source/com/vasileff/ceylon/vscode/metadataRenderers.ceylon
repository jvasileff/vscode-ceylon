String? renderCompletionDocumentation(CompletionDeclarationInfo completion) {
    // The first paragraph of the docs (if present) and container info
    value sb = StringBuilder();
    if (exists docInfo = completion.declarationInfo.docInfo) {
        docInfo.write(sb.append);
        sb.append("\n");
    }
    if (exists packageContainer
            =   completion.declarationInfo.packageContainer) {
        sb.append("Member of ``packageContainer``");
        sb.append("\n");
    }
    else if (exists classOrInterfaceContainer
            =   completion.declarationInfo.classOrInterfaceContainer) {
        sb.append("Member of ``classOrInterfaceContainer``");
        sb.append("\n");
    }
    return sb.string;
}

String? renderCompletionDetail(CompletionDeclarationInfo completion)
        // The type, may be null
    =>  completion.declarationInfo.signatureInfo.type;

String renderCompletionInsertText(CompletionDeclarationInfo completion)
    =>  renderCompletionLabel(completion, true);

String renderCompletionLabel(
        CompletionDeclarationInfo completion,
        "`true` if the result will be used for the 'insert' argument.
         Argument placeholders will be surrounded by `{{` `}}`."
        Boolean forInsertText = false) {

    // signature without return type, possibly with {{ and }} around arguments

    value sb
        =   StringBuilder();

    value declarationInfo
        =   completion.declarationInfo;

    value signatureInfo
        =   declarationInfo.signatureInfo;

    value annotationWithNoParameters
        =   signatureInfo.isAnnotation
            && (signatureInfo.parameterLists.first?.parameters?.empty else true);

    sb.append(signatureInfo.name);

    if (completion.withArguments && !annotationWithNoParameters) {
        for (parameterList in signatureInfo.parameterLists) {
            sb.append("(");
            variable value first = true;
            for (parameterInfo in parameterList.parameters) {
                if (!first) {
                    sb.append(", ");
                }
                first = false;
                if (forInsertText) {
                    sb.append("{{");
                }
                sb.append(parameterInfo.name);
                if (forInsertText) {
                    sb.append("}}");
                }
            }
            sb.append(")");
        }
    }
    else if (nonempty typeParameters = signatureInfo.typeParameters) {
        sb.append("<");
        if (forInsertText) {
            sb.append(",".join(typeParameters.map((tp) => "{{``tp``}}")));
        }
        else {
            sb.append(",".join(typeParameters));
        }
        sb.append(">");
    }
    return sb.string;
}
