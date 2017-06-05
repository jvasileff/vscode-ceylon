import ceylon.language.meta {
	type
}
String treeToString(Node node, Integer level = 0) {
	String name = type(node).declaration.name;
	
	value sb = StringBuilder();
	
	sb.append("\t".repeat(level) + name);
	
	switch (node)
	case (is Text) {
		sb.append(": \n" + "\t".repeat(level + 1) + "\"``node.text``\"" + "\n");
	}
	case (is CodeBlock) {
		sb.append(": \n" + "\t".repeat(level + 1) + "\"``node.text``\"" + "\n");
	}
	case (is Code) {
		sb.append(": \n" + "\t".repeat(level + 1) + "\"``node.text``\"" + "\n");
	}
	case (is Heading) {
		sb.append(" (``node.level``): \n");
	}
	case (is HtmlBlock) {
		sb.append(": \n" + "\t".repeat(level + 1) + "\"``node.text``\"" + "\n");
	}
	case (is HtmlInline) {
		sb.append(": \n" + "\t".repeat(level + 1) + "\"``node.text``\"" + "\n");
	}
	case (is OrderedList) {
		sb.append(" (start=``node.startsWith``, delimeter='``node.delimeter``', tight='``node.tight``'): \n");
	}
	case (is UnorderedList) {
		sb.append(" (bulletChar='``node.bulletChar``', tight='``node.tight``'): \n");
	}
	case (is Link) {
		sb.append(" (destination='``node.destination``', title='``node.title``'): \n");
	}
	case (is Image) {
		sb.append(" (destination='``node.destination``', title='``node.title``'): \n");
	}
	else {
		sb.append(": \n");
	}
	
	for (c in node.children) {
		sb.append(treeToString(c, level + 1));
	}
	
	return sb.string;
}
