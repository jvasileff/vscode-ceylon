shared class Paragraph() extends Block() {
	shared actual variable Node[] children = [];
	
	shared actual Type accept<Type>(Visitor<Type> visitor) => visitor.visitParagraph(this);
}
