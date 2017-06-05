"""
   Represents a Markdown block quote.
   
   Example, 
       > This is a block quote
   """
shared class BlockQuote() extends Block() {
	shared actual variable Node[] children = [];
	
	shared actual Type accept<Type>(Visitor<Type> visitor) => visitor.visitBlockQuote(this);
}
