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
    RangeImpl,
    PositionImpl
}

import org.antlr.runtime {
    CommonToken
}
import com.vasileff.ceylon.vscode.idecommon {
    getIdentifyingNode
}

shared
RangeImpl rangeForMessage(Message message) {
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
    return RangeImpl(PositionImpl(), PositionImpl());
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
