import ceylon.interop.java {
    CeylonIterable
}
import com.redhat.ceylon.model.typechecker.model {
    TypeParameter,
    Setter,
    TypeAlias,
    Package,
    Function,
    Class,
    Declaration,
    ClassOrInterface,
    ParameterList,
    Generic,
    TypedDeclaration,
    TypeDeclaration,
    Interface,
    ModelUtil,
    Functional,
    Value
}

DeclarationInfo getDeclarationInfo(Declaration declaration)
    =>  DeclarationInfo {
            signatureInfo
                =   getSignatureInfo(declaration);
            packageContainer
                =   if (is Package container = declaration.container,
                        exists name = container.qualifiedNameString)
                    then name
                    else null;
            classOrInterfaceContainer
                =   if (is ClassOrInterface container = declaration.container,
                        exists name = container.qualifiedNameString)
                    then name
                    else null;
            extendedType
                =   if (is Class declaration)
                    then declaration.extendedType?.asString()
                    else null;
            satisfiedTypes
                =   if (is TypeDeclaration declaration,
                            declaration is ClassOrInterface ||
                            declaration is TypeParameter,
                        !declaration.satisfiedTypes.empty)
                    then CeylonIterable(declaration.satisfiedTypes)
                            .collect((t) => t.asString())
                    else [];
            docInfo
                =   getDocInfo(declaration);
        };

SignatureInfo getSignatureInfo(Declaration declaration)
    =>  SignatureInfo {
            name
                =   declaration.name;
            kind
                =   if (ModelUtil.isConstructor(declaration)) then
                        DeclarationKind.constructor
                    else if (is Class declaration) then
                        DeclarationKind.classKind
                    else if (is Interface declaration) then
                        DeclarationKind.interfaceKind
                    else if (is TypeParameter declaration) then
                        DeclarationKind.typeParameter
                    else if (is TypeAlias declaration) then
                        DeclarationKind.typeAlias
                    else if (is Value declaration) then
                        DeclarationKind.valueKind
                    else if (is Setter declaration) then
                        DeclarationKind.setter
                    else if (is Function declaration) then
                        DeclarationKind.functionKind
                    else
                        DeclarationKind.unknown;
            type
                =   if (is TypedDeclaration declaration)
                    then declaration.type.asString()
                    else null;
            isVoid
                =   if (is Function declaration, declaration.declaredVoid)
                    then true
                    else false;
            isAnnotation
                =   declaration.annotation;
            typeParameters
                =   if (is Generic declaration)
                    then CeylonIterable(declaration.typeParameters)
                            .collect((tp) => tp.name)
                    else [];
            parameterLists
                =   if (is Functional declaration)
                    then CeylonIterable(declaration.parameterLists)
                            .collect(getParameterListInfo)
                    else [];
        };

ParameterListInfo getParameterListInfo(ParameterList parameterList)
    =>  ParameterListInfo {
            parameters
                =   CeylonIterable(parameterList.parameters).collect {
                        (parameter) => ParameterInfo {
                            name = parameter.name;
                            isVoid = parameter.declaredVoid;
                            type
                                =   if (parameter.sequenced)
                                    then parameter.declaration.unit.getIteratedType(
                                            parameter.type).asString()
                                    else parameter.type.asString();
                            sequenced
                                =   if (parameter.sequenced)
                                    then (parameter.atLeastOne then '+' else '*')
                                    else null;
                        };
            };
        };

DocInfo? getDocInfo(Declaration declaration) {
    variable value refined = declaration;
    while (true) {
        for (ann in CeylonIterable(declaration.annotations)) {
            if ("doc" == ann.name
                    && !ann.positionalArguments.empty) {
                value doc = ann.positionalArguments.get(0).string;
                String? docSource;
                if (refined != declaration) {
                    assert (is Declaration container = refined.container);
                    docSource = container.name + "." + refined.name;
                }
                else {
                    docSource = null;
                }
                return DocInfo {
                    doc = doc;
                    docSource = docSource;
                };
            }
        }
        value nextRefined = refined.refinedDeclaration;
        if (nextRefined == refined) {
            return null;
        }
        refined = nextRefined;
    }
}
