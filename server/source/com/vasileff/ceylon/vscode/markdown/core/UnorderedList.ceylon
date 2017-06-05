shared class UnorderedList(shared Character bulletChar) extends List() {
	shared actual variable Node[] children = [];
	
	shared actual Type accept<Type>(Visitor<Type> visitor) => visitor.visitUnorderedList(this);
	
}