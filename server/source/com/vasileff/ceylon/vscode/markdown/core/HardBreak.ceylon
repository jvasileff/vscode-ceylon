shared class HardBreak() extends Node() {
	shared actual variable Node[] children = [];
	
	shared actual Type accept<Type>(Visitor<Type> visitor) => visitor.visitHardBreak(this);
}