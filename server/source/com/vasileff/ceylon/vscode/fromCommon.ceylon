import com.redhat.ceylon.compiler.typechecker.parser {
    RecognitionError,
    LexError,
    CeylonParser
}
import com.redhat.ceylon.compiler.typechecker.tree {
    AnalysisMessage,
    CustomTree,
    Message,
    Tree,
    Node
}

import io.typefox.lsapi.impl {
    RangeImpl
}
import org.antlr.runtime {
    CommonToken
}
import com.vasileff.ceylon.vscode.internal {
    newRange,
    newPosition
}

RangeImpl? rangeForMessage(Message message) {
    if (exists [startLine, startColumn, endLine, endColumn]
            =   messageLocation(message)) {
        return newRange {
            newPosition {
                line = startLine - 1;
                character = startColumn;
            };
            newPosition {
                line = endLine - 1;
                character = endColumn + 1;
            };
        };
    }
    return null;
}

Integer[4]? messageLocation(Message error) {
    Integer startLine;
    Integer startColumn;
    Integer endLine;
    Integer endColumn;

    if (is RecognitionError error) {
        value recognitionError = error;
        value re = recognitionError.recognitionException;
        if (is LexError error) {
            startLine = re.line;
            startColumn = re.charPositionInLine;
            endLine = re.line;
            endColumn = re.charPositionInLine;
        }
        else if (is CommonToken token = re.token) {
            // TODO if eof on an empty line, try to mark the error on the previous
            //      line instead? But then, that line might be empty too.
            value eofAdjust = (token.type == CeylonParser.eof) then -1 else 0;
            startLine = token.line;
            startColumn = largest(0, token.charPositionInLine + eofAdjust);
            endLine = token.line;
            endColumn = startColumn + token.stopIndex - token.startIndex;
        }
        else {
            return null;
        }
    }
    else if (is AnalysisMessage error) {
        value analysisMessage = error;
        value treeNode = analysisMessage.treeNode;
        value errorNode = getIdentifyingNode(treeNode) else treeNode;
        if (is CommonToken token = errorNode.token) {
            startLine = token.line;
            startColumn = token.charPositionInLine;
            endLine = errorNode.endToken.line;
            endColumn = errorNode.endToken.charPositionInLine
                + errorNode.endToken.text.size - 1;
        }
        else {
            return null;
        }
    }
    else {
        return null;
    }
    return [startLine, startColumn, endLine, endColumn];
}

Node? getIdentifyingNode(Node? node) {
    switch (node)
    case (is Tree.Declaration) {
        if (exists id = node.identifier) {
            return id;
        } else if (node is Tree.MissingDeclaration) {
            return null;
        } else {
            //TODO: whoah! this is really ugly!
            return
                if (exists tok = node.mainToken)
                then Tree.Identifier(CommonToken(tok))
                else null;
        }
    }
    case (is Tree.ModuleDescriptor) {
        if (exists ip = node.importPath) {
            return ip;
        }
    }
    case (is Tree.PackageDescriptor) {
        if (exists ip = node.importPath) {
            return ip;
        }
    }
    case (is Tree.Import) {
        if (exists ip = node.importPath) {
            return ip;
        }
    }
    case (is Tree.ImportModule) {
        if (exists ip = node.importPath) {
            return ip;
        } else if (exists p = node.quotedLiteral) {
            return p;
        }
    }
    case (is Tree.NamedArgument) {
        if (exists id = node.identifier) {
            return id;
        }
    }
    case (is Tree.StaticMemberOrTypeExpression) {
        if (exists id = node.identifier) {
            return id;
        }
    }
    case (is CustomTree.ExtendedTypeExpression) {
        //TODO: whoah! this is really ugly!
        return node.type.identifier;
    }
    case (is Tree.SimpleType) {
        if (exists id = node.identifier) {
            return id;
        }
    }
    case (is Tree.ImportMemberOrType) {
        if (exists id = node.identifier) {
            return id;
        }
    }
    case (is Tree.InitializerParameter) {
        if (exists id = node.identifier) {
            return id;
        }
    }
    case (is Tree.MemberLiteral) {
        if (exists id = node.identifier) {
            return id;
        }
    }
    case (is Tree.TypeLiteral) {
        return getIdentifyingNode(node.type);
    }
    else {}
    //TODO: this would be better for navigation to refinements
    //      so I guess we should split this method into two
    //      versions :-/
    /*else if (node instanceof Tree.SpecifierStatement) {
        Tree.SpecifierStatement st = (Tree.SpecifierStatement) node;
        if (st.getRefinement()) {
            Tree.Term lhs = st.getBaseMemberExpression();
            while (lhs instanceof Tree.ParameterizedExpression) {
                lhs = ((Tree.ParameterizedExpression) lhs).getPrimary();
            }
            if (lhs instanceof Tree.StaticMemberOrTypeExpression) {
                return ((Tree.StaticMemberOrTypeExpression) lhs).getIdentifier();
            }
        }
        return node;
     }*/
    return node;
}
