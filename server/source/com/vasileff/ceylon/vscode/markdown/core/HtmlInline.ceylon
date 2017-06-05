shared class HtmlInline(shared String text) extends Node() {
	shared actual variable Node[] children = [];
	
	shared actual Type accept<Type>(Visitor<Type> visitor) => visitor.visitHtmlInline(this);
}