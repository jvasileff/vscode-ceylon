import com.redhat.ceylon.compiler.typechecker.parser {
    RecognitionError,
    LexError,
    CeylonParser
}
import com.redhat.ceylon.compiler.typechecker.tree {
    AnalysisMessage,
    Message
}
import com.vasileff.ceylon.vscode.idecommon {
    getIdentifyingNode
}

import org.antlr.runtime {
    CommonToken
}
import org.eclipse.lsp4j {
    Range,
    Position
}

shared
Range rangeForMessage(Message message) {
    if (exists [startLine, startColumn, endLine, endColumn]
            =   messageLocation(message)) {
        return newRange {
            newPosition {
                line = startLine;
                character = startColumn;
            };
            newPosition {
                line = endLine;
                character = endColumn;
            };
        };
    }
    return Range(Position(), Position());
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
            startLine = re.line - 1;
            startColumn = re.charPositionInLine;
            endLine = re.line - 1;
            endColumn = re.charPositionInLine + 1;
        }
        else if (is CommonToken token = re.token) {
            // TODO if eof on an empty line, try to mark the error on the previous
            //      line instead? But then, that line might be empty too.
            value eofAdjust = (token.type == CeylonParser.eof) then -1 else 0;
            startLine = token.line - 1;
            startColumn = largest(0, token.charPositionInLine + eofAdjust);
            endLine = token.line - 1;
            endColumn = startColumn + token.stopIndex - token.startIndex + 1;
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
            startLine = token.line - 1;
            startColumn = token.charPositionInLine;
            endLine = errorNode.endToken.line - 1;
            endColumn = errorNode.endToken.charPositionInLine
                + errorNode.endToken.text.size;
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
