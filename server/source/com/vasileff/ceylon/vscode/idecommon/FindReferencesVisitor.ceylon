import ceylon.collection {
    HashSet,
    SetMutator
}
import ceylon.interop.java {
    JavaSet
}

import com.redhat.ceylon.compiler.typechecker.tree {
    TreeUtil {
        formatPath
    },
    Node,
    Tree,
    Visitor,
    CustomTree {
        GuardedVariable
    }
}
import com.redhat.ceylon.model.typechecker.model {
    Constructor,
    Declaration,
    Package,
    Parameter,
    Referenceable,
    Setter,
    Value
}

import java.util {
    JSet=Set
}

shared class FindReferencesVisitor(Referenceable dec) extends Visitor() {
    value nodes = HashSet<Node>();
    
    shared Set<Node> referenceNodes => nodes;
    shared JSet<Node> referenceNodeSet => JavaSet(nodes);
    
    shared SetMutator<Node> nodesMutator => nodes;
    
    function originalDeclaration(Value val) {
        variable value result = val;
        while (is Value original = result.originalDeclaration, 
            original!=result && original!=val) {
            result = original;
        }
        return result;
    }
    
    function initialDeclaration(Referenceable declaration) {
        switch (declaration)
        case (is Value) {
            value original = originalDeclaration(declaration);
            if (exists param = original.initializerParameter,
                is Setter setter = param.declaration) {
                return setter.getter else setter;
            }
            else {
                return original;
            }
        }
        case (is Setter) {
            return declaration.getter else declaration;
        }
        case (is Constructor) {
            if (!declaration.name exists,
                exists extended = declaration.extendedType) {
                return extended.declaration;
            }
            else {
                return declaration;
            }
        }    
        else {
            return declaration;
        }
    }
    
    shared variable Referenceable declaration 
            = initialDeclaration(dec);
    
    shared default Boolean isReference(Parameter|Declaration? param) {
        if (is Parameter param) {
            return isReference(param.model);
        } else if (is Declaration ref = param) {
            return isRefinedDeclarationReference(ref)
                || isSetterParameterReference(ref);
        }
        else {
            return false;
        }
    }
    
    suppressWarnings("deprecation", "suppressesNothing")
    shared default Boolean isRefinedDeclarationReference(Declaration ref) 
            => if (is Declaration dec = declaration) 
            then dec.refines(ref) else false;
    
    shared default Boolean isSetterParameterReference(Declaration ref) {
        if (is Value ref, 
            exists param = ref.initializerParameter,
            is Setter setter = param.declaration) {
            return isReference(setter)
                || isReference(setter.getter);
        } else {
            return false;
        }
    }
    
    Tree.Variable? getConditionVariable(Tree.Condition c) {
        if (is Tree.ExistsOrNonemptyCondition eonc = c, 
            is Tree.Variable st = eonc.variable) {
            
            return st;
        }
        
        if (is Tree.IsCondition ic = c) {
            return ic.variable;
        }
        
        return null;
    }
    
    shared actual void visit(Tree.CaseClause that) {
        if (is Tree.IsCase ic = that.caseItem,
            exists var = ic.variable) {
            
            value vd = var.declarationModel;
            if (exists od = vd.originalDeclaration,
                od==declaration) {
                
                value d = declaration;
                declaration = vd;
                if (exists b = that.block) {
                    b.visit(this);
                }
                
                if (exists e = that.expression) {
                    e.visit(this);
                }
                
                declaration = d;
                return;
            }
        }
        
        super.visit(that);
    }
    
    shared actual void visit(Tree.WhileClause that) {
        if (exists cl = that.conditionList) {
            value conditions = cl.conditions;
            variable value i = 0;
            while (i < conditions.size()) {
                value c = conditions.get(i);
                value var = getConditionVariable(c);
                if (exists var,
                    var.type is Tree.SyntheticVariable) {
                    
                    value vd = var.declarationModel;
                    if (exists od = vd.originalDeclaration,
                        od==declaration) {
                        
                        variable value j = 0;
                        while (j <= i) {
                            value oc = conditions.get(j);
                            oc.visit(this);
                            j++;
                        }
                        
                        value d = declaration;
                        declaration = vd;
                        that.block.visit(this);
                        j = i;
                        while (j < conditions.size()) {
                            value oc = conditions.get(j);
                            oc.visit(this);
                            j++;
                        }
                        
                        declaration = d;
                        return;
                    }
                }
                
                i++;
            }
        }

        super.visit(that);
    }
    
    shared actual void visit(Tree.IfClause that) {
        if (exists cl = that.conditionList) {
            value conditions = cl.conditions;
            
            variable value i = 0;
            while (i < conditions.size()) {
                value c = conditions.get(i);
                value var = getConditionVariable(c);
                if (exists var,
                    var.type is Tree.SyntheticVariable) {
                    
                    value vd = var.declarationModel;
                    if (exists od = vd.originalDeclaration,
                        od==declaration) {
                        
                        variable value j = 0;
                        while (j <= i) {
                            value oc = conditions.get(j);
                            oc.visit(this);
                            j++;
                        }
                        
                        value d = declaration;
                        declaration = vd;
                        if (exists b = that.block) {
                            b.visit(this);
                        }
                        
                        if (exists e = that.expression) {
                            e.visit(this);
                        }
                        
                        j = i + 1;
                        while (j < conditions.size()) {
                            value oc = conditions.get(j);
                            oc.visit(this);
                            j++;
                        }
                        
                        declaration = d;
                        return;
                    }
                }
                
                i++;
            }
        }

        super.visit(that);
    }
    
    shared actual void visit(Tree.ElseClause that) {
        if (exists var = that.variable) {
            value vd = var.declarationModel;
            if (exists od = vd.originalDeclaration, 
                od==declaration) {
                value d = declaration;
                declaration = vd;
                if (exists b = that.block) {
                    b.visit(this);
                }
                
                if (exists e = that.expression) {
                    e.visit(this);
                }
                
                declaration = d;
                return;
            }
        }
        
        super.visit(that);
    }
    
    shared actual void visit(Tree.Variable that) {
        if (is GuardedVariable that) {
            value d = that.declarationModel;
            if (exists od = d.originalDeclaration,
                od==declaration) {
                
                declaration = d;
            }
        } else {
            super.visit(that);
        }
    }
    
    shared actual void visit(Tree.Body body) {
        value d = declaration;
        for (st in body.statements) {
            if (is Tree.Assertion  that = st) {
                value cl = that.conditionList;
                for (c in cl.conditions) {
                    value var = getConditionVariable(c);
                    if (exists var,
                        var.type is Tree.SyntheticVariable) {
                        
                        value vd = var.declarationModel;
                        if (exists od = vd.originalDeclaration,
                            od==declaration) {
                            
                            c.visit(this);
                            declaration = vd;
                            break;
                        }
                    }
                }
            }
            
            st.visit(this);
        }
        
        declaration = d;
    }
    
    shared actual void visit(Tree.ExtendedTypeExpression that) {
    }
    
    shared actual void visit(Tree.StaticMemberOrTypeExpression that) {
        if (isReference(that.declaration)) {
            nodes.add(that);
        }
        
        super.visit(that);
    }
    
    shared actual void visit(Tree.MemberLiteral that) {
        if (isReference(that.declaration)) {
            nodes.add(that);
        }
        
        super.visit(that);
    }
    
    shared actual void visit(Tree.TypedArgument that) {
        if (isReference(that.parameter)) {
            nodes.add(that);
        }
        
        super.visit(that);
    }
    
    shared actual void visit(Tree.SpecifiedArgument that) {
        if (that.identifier exists, 
            that.identifier.token exists, 
            isReference(that.parameter)) {
            
            nodes.add(that);
        }
        
        super.visit(that);
    }
    
    shared actual void visit(Tree.SimpleType that) {
        if (exists type = that.typeModel,
            isReference(type.declaration)) {
            
            nodes.add(that);
        }
        
        super.visit(that);
    }
    
    shared actual void visit(Tree.ImportMemberOrType that) {
        if (isReference(that.declarationModel)) {
            nodes.add(that);
        }
        
        super.visit(that);
    }
    
    shared actual void visit(Tree.Import that) {
        super.visit(that);
        if (is Package pkg = declaration) {
            value path = formatPath(that.importPath.identifiers);
            if (path==pkg.nameAsString) {
                nodes.add(that);
            }
        }
    }
    
    shared actual void visit(Tree.ImportModule that) {
        super.visit(that);
        
//        if (is Module mod = declaration,
//            exists path = finder.getImportedModuleName(that),
//            path==declaration.nameAsString) {
//
//            nodes.add(that);
//        }
    }
    
    shared actual default void visit(Tree.InitializerParameter that) {
        if (isReference(that.parameterModel)) {
            nodes.add(that);
        } else {
            super.visit(that);
        }
    }
    
    shared actual void visit(Tree.TypeConstraint that) {
        if (isReference(that.declarationModel)) {
            nodes.add(that);
        } else {
            super.visit(that);
        }
    }
}




