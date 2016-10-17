import org.antlr.runtime {
    CommonToken
}
import com.redhat.ceylon.compiler.typechecker.tree {
    CustomTree,
    Tree,
    Node
}

shared
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
