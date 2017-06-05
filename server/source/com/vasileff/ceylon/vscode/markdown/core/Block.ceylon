shared abstract class Block(shared variable Boolean open = true) extends Node() {
	shared void closeBlock() => open = false;
}
