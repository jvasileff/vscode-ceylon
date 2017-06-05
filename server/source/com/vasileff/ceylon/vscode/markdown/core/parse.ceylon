import ceylon.collection {
	HashMap
}

late variable HashMap<String,Link> referenceMap;

"""
   Method that parses the input text and returns an [[AST|Document]]. 
   This AST can be visited by implementing a [[Visitor]].
   
   Example, 
       value tree = parse("markdownText");
"""
shared Document parse(
	"The Markdown text to be parsed."
	String markdown) {
	
	Document internalDoc = Document();
	referenceMap = HashMap<String,Link>();
	
	for (line in markdown.lines) {
		parseLine(line, internalDoc);
	}
	
	value document = inlineParser(internalDoc);
	
	return document;
}
