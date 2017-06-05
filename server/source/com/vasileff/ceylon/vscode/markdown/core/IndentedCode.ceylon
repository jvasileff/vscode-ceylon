shared class IndentedCode(String text) extends CodeBlock(text) {
	shared actual variable Node[] children = [];
	
	shared actual Type accept<Type>(Visitor<Type> visitor) => visitor.visitIndentedCode(this);
}