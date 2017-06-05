shared class Link(shared String destination, shared String title = "") extends Node() {
	shared actual variable Node[] children = [];
	
	shared actual Type accept<Type>(Visitor<Type> visitor) => visitor.visitLink(this);
}
