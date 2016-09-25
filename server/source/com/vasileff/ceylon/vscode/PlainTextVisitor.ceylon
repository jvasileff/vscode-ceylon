import ceylon.markdown.core {
	Visitor,
	BlockQuote,
	Code,
	Document,
	Emphasis,
	FencedCode,
	HardBreak,
	Heading,
	HtmlBlock,
	HtmlInline,
	Image,
	IndentedCode,
	Link,
	ListItem,
	OrderedList,
	Paragraph,
	SoftBreak,
	StrongEmphasis,
	Text,
	ThematicBreak,
	UnorderedList,
	Node
}

"""
   An implementation of the Markdown [[Visitor]] that converts Markdown to plain text.
"""
shared class PlainTextVisitor(void write(String string)) satisfies Visitor<Anything> {
	shared actual void visitBlockQuote(BlockQuote blockQuote) {
		visitChildren(blockQuote);
		write("\n");
	}
	
	shared actual void visitCode(Code code) {
		write("`");
		write(code.text);
		write("`");
	}
	
	shared actual void visitDocument(Document document) => visitChildren(document);
	
	shared actual void visitEmphasis(Emphasis emphasis) {
		write("*");
		visitChildren(emphasis);
		write("*");
	}

	shared actual void visitFencedCode(FencedCode fencedCode) {
		write(fencedCode.text);
		write("\n");
	}
	
	shared actual void visitHardBreak(HardBreak hardBreak) => write("\n");
	
	shared actual void visitHeading(Heading heading) {
		visitChildren(heading);
		write("\n");
		if (heading.level > 1) {
			write("-----");
		} else {
			write("=====");
		}
		write("\n\n");
	}
	
	shared actual void visitHtmlBlock(HtmlBlock htmlBlock) => write(htmlBlock.text);
	
	shared actual void visitHtmlInline(HtmlInline htmlInline) => write(htmlInline.text);
	
	shared actual void visitImage(Image image) => visitChildren(image);
	
	shared actual void visitIndentedCode(IndentedCode indentedCode) {
		write(indentedCode.text);
		write("\n");
	}
	
	shared actual void visitLink(Link link) => visitChildren(link);
	
	shared actual void visitListItem(ListItem listItem) {
		visitChildren(listItem);
	}
	
	shared actual void visitOrderedList(OrderedList orderedList) {
		visitChildren(orderedList);
		write("\n");
	}
	
	shared actual void visitParagraph(Paragraph paragraph) {
		visitChildren(paragraph);
		write("\n");
	}
	
	shared actual void visitSoftBreak(SoftBreak softBreak) => write(" ");
	
	shared actual void visitStrongEmphasis(StrongEmphasis strongEmphasis) {
		write("**");
		visitChildren(strongEmphasis);
		write("**");
	}
	
	shared actual void visitText(Text text) => write(text.text);
	
	shared actual void visitThematicBreak(ThematicBreak thematicBreak) => write("*****\n\n");
	
	shared actual void visitUnorderedList(UnorderedList unorderedList) {
		visitChildren(unorderedList);
		write("\n");
	}
	
	shared void visitChildren(Node node) {
		
		variable Integer i = 0;
		for (child in node.children) {
			if (is OrderedList node) {
				write((node.startsWith + i++).string + node.delimeter.string + " ");
			} else if (is UnorderedList node) {
				write(node.bulletChar.string + " ");
			}
			child.accept(this);
		}
	}
}

"""
   Render Markdown as plain text.
   
   Usage: 
       value sb = StringBuilder();
       
       renderPlainText(tree, sb.append);
"""
shared void renderPlainText(Node node, void write(String string)) {
	node.accept(PlainTextVisitor(write));
}
