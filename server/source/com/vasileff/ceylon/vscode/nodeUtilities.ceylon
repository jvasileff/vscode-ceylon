import com.redhat.ceylon.compiler.typechecker.tree {
    Node
}

import org.antlr.runtime {
    CommonToken
}
import org.eclipse.lsp4j {
    Range
}

shared
Range? rangeForNode(Node node)
    =>  if (is CommonToken token = node.token)
        then newRange {
                newPosition {
                    line = node.token.line - 1;
                    character = node.token.charPositionInLine;
                };
                newPosition {
                    line = node.endToken.line - 1;
                    character = node.endToken.charPositionInLine
                        + node.endToken.text.size;
                };
            }
        else null;
