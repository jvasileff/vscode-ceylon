shared class OrderedList(shared Integer startsWith, shared Character delimeter) extends List() {
	shared actual variable Node[] children = [];
	
	shared actual Type accept<Type>(Visitor<Type> visitor) => visitor.visitOrderedList(this);
}