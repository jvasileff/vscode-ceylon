"""
   An AST visitor for Markdown.
"""
shared interface Visitor<Type> {
	shared formal Type visitText(Text text);
	shared formal Type visitParagraph(Paragraph paragraph);
	shared formal Type visitBlockQuote(BlockQuote blockQuote);
	shared formal Type visitDocument(Document document);
	shared formal Type visitCode(Code code);
	shared formal Type visitEmphasis(Emphasis emphasis);
	shared formal Type visitFencedCode(FencedCode fencedCode);
	shared formal Type visitHardBreak(HardBreak hardBreak);
	shared formal Type visitHeading(Heading heading);
	shared formal Type visitHtmlBlock(HtmlBlock htmlBlock);
	shared formal Type visitImage(Image image);
	shared formal Type visitIndentedCode(IndentedCode indentedCode);
	shared formal Type visitLink(Link link);
	shared formal Type visitOrderedList(OrderedList orderedList);
	shared formal Type visitListItem(ListItem listItem);
	shared formal Type visitSoftBreak(SoftBreak softBreak);
	shared formal Type visitStrongEmphasis(StrongEmphasis strongEmphasis);
	shared formal Type visitThematicBreak(ThematicBreak thematicBreak);
	shared formal Type visitUnorderedList(UnorderedList unorderedList);
	shared formal Type visitHtmlInline(HtmlInline htmlInline);
}
