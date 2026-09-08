extends RefCounted
## A lossless source token. Offsets and columns count Unicode code points;
## lines and columns are zero-based, and end positions are exclusive.

enum Kind {
	UNKNOWN, IDENTIFIER, NUMBER, STRING, ANNOTATION,
	VAR, CONST, FUNC, CLASS, CLASS_NAME, EXTENDS, SIGNAL, ENUM, STATIC,
	IF, ELIF, ELSE, FOR, WHILE, MATCH, WHEN,
	RETURN, BREAK, CONTINUE, PASS, AWAIT, AND, OR, NOT, AS, IS, IN,
	TRUE, FALSE, NULL, SELF, SUPER, BREAKPOINT,
	OPERATOR, LEFT_PAREN, RIGHT_PAREN, LEFT_BRACKET, RIGHT_BRACKET,
	LEFT_BRACE, RIGHT_BRACE, COMMA, COLON, SEMICOLON, DOT,
	DOLLAR, PERCENT, BACKSLASH, SPACE, TAB, NEWLINE, COMMENT,
}

var kind: int
var text: String
var start_offset: int
var end_offset: int
var start_line: int
var start_column: int
var end_line: int
var end_column: int


func is_trivia() -> bool:
	return kind in [Kind.SPACE, Kind.TAB, Kind.NEWLINE, Kind.COMMENT]
