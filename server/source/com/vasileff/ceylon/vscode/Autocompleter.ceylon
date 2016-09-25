import ceylon.interop.java {
    CeylonMap
}

import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree,
    Visitor
}
import com.redhat.ceylon.model.typechecker.model {
    DeclarationWithProximity,
    Functional,
    Scope,
    Type,
    TypeDeclaration,
    Unit,
    Declaration
}

import java.lang {
    JString=String
}
import java.util {
    JMap=Map,
    Collections {
        emptyMap
    }
}

class CompletionDeclarationInfo(
        shared DeclarationInfo declarationInfo,
        shared Boolean withArguments) {}

class Autocompleter(String documentId,
        Integer row, Integer col,
        {PhasedUnit*} phasedUnits) {

    value noCompletions = emptyMap<JString,DeclarationWithProximity>();

    shared [Node,String]? selectedNode {
        for (pu in phasedUnits) {
            if (documentId == pu.unitFile.path) {
                value fiv = FindIdentifierVisitor(row,col);
                pu.compilationUnit.visit(fiv);
                if (exists [node, text] = fiv.result) {
                    value fpv = FindParentVisitor(node);
                    pu.compilationUnit.visit(fpv);
                    return [fpv.node, text];
                }
            }
        }
        return null;
    }

    shared [CompletionDeclarationInfo*] completions {
        if (exists [node, prefix] = selectedNode) {
            Unit unit = node.unit;
            Scope scope = node.scope;
            JMap<JString,DeclarationWithProximity> completions;
            switch (node)
            case (is Tree.QualifiedMemberOrTypeExpression) {
                if (node.staticMethodReference) {
                    assert (is Tree.StaticMemberOrTypeExpression smte = node.primary);
                    // TODO send patch upstream for optional below
                    assert (is TypeDeclaration? td = smte.declaration);
                    if (exists td) {
                        completions = td.getMatchingMemberDeclarations(unit, scope, prefix, 0, null);
                    }
                    else {
                        completions = noCompletions;
                    }
                }
                else {
                    Type type;
                    if (exists t = node.primary.typeModel) {
                        switch (op = node.memberOperator)
                        case (is Tree.SafeMemberOp) {
                            type = unit.getDefiniteType(t);
                        }
                        case (is Tree.SpreadOp) {
                            type = unit.getIteratedType(t);
                        }
                        else {
                            type = t;
                        }
                        completions = type.declaration.getMatchingMemberDeclarations(unit, scope, prefix, 0, null);
                    }
                    else {
                        completions = noCompletions;
                    }
                }
            }
            case (is Tree.BaseMemberOrTypeExpression) {
                completions = node.scope.getMatchingDeclarations(unit, prefix, 0, null);
            }
            case (is Tree.BaseType) {
                completions = node.scope.getMatchingDeclarations(unit, prefix, 0, null);
            }
            case (is Tree.QualifiedType) {
                if (exists type = node.outerType.typeModel) {
                    completions = type.declaration.getMatchingMemberDeclarations(unit, scope, prefix, 0, null);
                }
                else {
                    completions = noCompletions; 
                }
            }
            case (is Tree.Variable) {
                completions = node.scope.getMatchingDeclarations(unit, prefix, 0, null);
            }
            else {
                //TODO!!
                completions = noCompletions;
            }

            return CeylonMap(completions).items
                .map(DeclarationWithProximity.declaration).distinct
                .collect((declaration)
                    =>  CompletionDeclarationInfo {
                            declarationInfo
                                =   getDeclarationInfo(declaration);
                            withArguments
                                =   !declaration is TypeDeclaration
                                        && declaration is Functional;
                        });
        }
        else {
            return [];
        }
    }
}

class FindIdentifierVisitor(Integer row, Integer col) extends Visitor() {

    shared variable [Node,String]? result = null;

    shared actual void visit(Tree.Identifier that) {
        if (exists token = that.token, token.line == row) {
            Integer col0 = that.token.charPositionInLine;
            Integer col1 = col0 + that.text.size;
            if (col >= col0, col <= col1) {
                result = [that, that.text[0:col-col0]];
            }
        }
        
        super.visit(that);
    }

    shared actual void visit(Tree.MemberOperator that) {
        if (exists token = that.token, token.line == row) {
            Integer col1 = that.token.charPositionInLine + that.text.size;
            if (col == col1) {
                result = [that, ""];
            }
        }
        
        super.visit(that);
    }
}

class FindParentVisitor(shared variable Node node) extends Visitor() {

    variable Boolean found = false;

    shared actual void visitAny(Node node) {
        if (found) {
            return;
        }
        
        super.visitAny(node);
    }

    shared actual void visit(Tree.StaticMemberOrTypeExpression that) {
        if (found) {
            return;
        }
        
        if (exists id = that.identifier, id == node) {
            node = that;
            found = true;
            return;
        }
        
        super.visit(that);
    }

    shared actual void visit(Tree.QualifiedMemberOrTypeExpression that) {
        if (found) {
            return;
        }
        
        if (exists op = that.memberOperator, op == node) {
            node = that;
            found = true;
            return;
        }
        
        super.visit(that);
    }

    shared actual void visit(Tree.ImportMemberOrType that) {
        if (found) {
            return;
        }
        
        if (exists id = that.identifier, id == node) {
            node = that;
            found = true;
            return;
        }
        
        super.visit(that);
    }

    shared actual void visit(Tree.Alias that) {
        if (found) {
            return;
        }
        
        if (exists id = that.identifier, id == node) {
            node = that;
            found = true;
            return;
        }
        
        super.visit(that);
    }
    
    shared actual void visit(Tree.Declaration that) {
        if (found) {
            return;
        }
        
        if (exists id = that.identifier, id == node) {
            node = that;
            found = true;
            return;
        }
        
        super.visit(that);
    }
    
    shared actual void visit(Tree.InitializerParameter that) {
        if (found) {
            return;
        }
        
        if (exists id = that.identifier, id == node) {
            node = that;
            found = true;
            return;
        }
        
        super.visit(that);
    }
    
    shared actual void visit(Tree.SimpleType that) {
        if (found) {
            return;
        }
        
        if (exists id = that.identifier, id == node) {
            node = that;
            found = true;
            return;
        }
        
        super.visit(that);
    }
    
    shared actual void visit(Tree.MemberLiteral that) {
        if (found) {
            return;
        }
        
        if (exists id = that.identifier, id == node) {
            node = that;
            found = true;
            return;
        }
        
        super.visit(that);
    }
    
    shared actual void visit(Tree.SatisfiesCondition that) {
        if (found) {
            return;
        }
        
        if (exists id = that.identifier, id == node) {
            node = that;
            found = true;
            return;
        }
        
        super.visit(that);
    }
    
    shared actual void visit(Tree.NamedArgument that) {
        if (found) {
            return;
        }
        
        if (exists id = that.identifier, id == node) {
            node = that;
            found = true;
            return;
        }
        
        super.visit(that);
    }
}

Declaration? findDeclaration(
        String documentId, Integer row, Integer col,
        [PhasedUnit*] phasedUnits) {
    if (exists [node, _] =
            Autocompleter {
                documentId = documentId;
                row = row;
                col = col;
                phasedUnits = phasedUnits;
            }.selectedNode) {
        switch (node)
        case (is Tree.StaticMemberOrTypeExpression) {
            return node.declaration;
        }
        case (is Tree.SimpleType) {
            return node.declarationModel;
        }
        case (is Tree.Declaration) {
            return node.declarationModel;
        }
        case (is Tree.NamedArgument) {
            return node.parameter.model;
        }
        else {
            return null;
        }
    }
    else {
        return null;
    }
}
