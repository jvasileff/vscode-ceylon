shared class HtmlBlock(shared variable String text, shared Integer type) extends Block() {
	shared actual variable Node[] children = [];
	
	shared actual Type accept<Type>(Visitor<Type> visitor) => visitor.visitHtmlBlock(this);
}