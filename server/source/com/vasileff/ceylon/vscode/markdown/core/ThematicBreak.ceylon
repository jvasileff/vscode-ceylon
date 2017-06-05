shared class ThematicBreak() extends Block() {
	shared actual variable Node[] children = [];
	
	shared actual Type accept<Type>(Visitor<Type> visitor) => visitor.visitThematicBreak(this);
}