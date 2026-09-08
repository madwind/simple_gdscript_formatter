extends RefCounted
## Preserves every character, including trivia and incomplete editor input.

const Token = preload("token.gd")
const K = Token.Kind
const KEYWORDS = {
	"var": K.VAR, "const": K.CONST, "func": K.FUNC, "class": K.CLASS,
	"class_name": K.CLASS_NAME, "extends": K.EXTENDS, "signal": K.SIGNAL,
	"enum": K.ENUM, "static": K.STATIC, "if": K.IF, "elif": K.ELIF,
	"else": K.ELSE, "for": K.FOR, "while": K.WHILE, "match": K.MATCH,
	"when": K.WHEN, "return": K.RETURN, "break": K.BREAK,
	"continue": K.CONTINUE, "pass": K.PASS, "await": K.AWAIT,
	"and": K.AND, "or": K.OR, "not": K.NOT, "as": K.AS, "is": K.IS,
	"in": K.IN, "true": K.TRUE, "false": K.FALSE, "null": K.NULL,
	"self": K.SELF, "super": K.SUPER, "breakpoint": K.BREAKPOINT,
}
const PUNCTUATION = {
	"(": K.LEFT_PAREN, ")": K.RIGHT_PAREN, "[": K.LEFT_BRACKET,
	"]": K.RIGHT_BRACKET, "{": K.LEFT_BRACE, "}": K.RIGHT_BRACE,
	",": K.COMMA, ":": K.COLON, ";": K.SEMICOLON, ".": K.DOT,
	"$": K.DOLLAR, "%": K.PERCENT, "\\": K.BACKSLASH,
}
const OPERATORS = [
	"**=", "<<=", ">>=", "**", "<<", ">>", "==", "!=", ">=", "<=",
	"&&", "||", "+=", "-=", "*=", "/=", "%=", "&=", "^=", "|=",
	":=", "->", "..", "+", "-", "*", "/", "=", "<", ">", "&", "|", "^", "~", "!",
]

var source: String
var offset := 0
var line := 0
var column := 0
var tokens: Array = []
var errors: Array[String] = []


func tokenize(code: String) -> Array:
	source = code
	offset = 0
	line = 0
	column = 0
	tokens = []
	errors = []
	while offset < source.length():
		_scan_token()
	return tokens


func _scan_token() -> void:
	var start := offset
	var start_line := line
	var start_column := column
	var kind := K.UNKNOWN
	var c := _peek()
	if c == " " or c == "\t":
		kind = K.SPACE if c == " " else K.TAB
		while _peek() == c:
			_advance()
	elif c == "\n" or c == "\r":
		kind = K.NEWLINE
		_advance()
	elif c == "#":
		kind = K.COMMENT
		while offset < source.length() and _peek() not in ["\r", "\n"]:
			_advance()
	elif c in ["'", '"'] or (c in ["&", "^", "r"] and _peek(1) in ["'", '"']):
		kind = K.STRING
		if c in ["&", "^", "r"]:
			_advance()
		_scan_string()
	elif c == "@":
		kind = K.ANNOTATION
		_advance()
		while _identifier_part(_peek()):
			_advance()
	elif _digit(c) or (c == "." and _digit(_peek(1))):
		kind = K.NUMBER
		_scan_number()
	elif _identifier_start(c):
		_advance()
		while _identifier_part(_peek()):
			_advance()
		kind = KEYWORDS.get(source.substr(start, offset - start), K.IDENTIFIER)
	else:
		for operator: String in OPERATORS:
			if source.substr(offset, operator.length()) == operator:
				kind = K.OPERATOR
				for _i in operator.length():
					_advance()
				break
		if offset == start:
			kind = PUNCTUATION.get(c, K.UNKNOWN)
			_advance()
	var token = Token.new()
	token.kind = kind
	token.text = source.substr(start, offset - start)
	token.start_offset = start
	token.end_offset = offset
	token.start_line = start_line
	token.start_column = start_column
	token.end_line = line
	token.end_column = column
	tokens.append(token)
	if kind == K.UNKNOWN:
		errors.append("Unknown token at %d:%d" % [start_line + 1, start_column + 1])


func _scan_string() -> void:
	var quote := _peek()
	var delimiter := quote
	if source.substr(offset, 3) == quote.repeat(3):
		delimiter = quote.repeat(3)
	for _i in delimiter.length():
		_advance()
	while offset < source.length():
		if _peek() == "\\":
			_advance()
			if offset < source.length():
				_advance()
		elif source.substr(offset, delimiter.length()) == delimiter:
			for _i in delimiter.length():
				_advance()
			return
		else:
			_advance()
	errors.append("Unterminated string at end of source")


func _scan_number() -> void:
	if _peek() == "0" and _peek(1).to_lower() in ["x", "b"]:
		_advance()
		var base := _peek().to_lower()
		_advance()
		var digits := "0123456789abcdef_" if base == "x" else "01_"
		while not _peek().is_empty() and _peek().to_lower() in digits:
			_advance()
		return
	while _digit(_peek()) or _peek() == "_":
		_advance()
	if _peek() == "." and _peek(1) != ".":
		_advance()
		while _digit(_peek()) or _peek() == "_":
			_advance()
	if _peek().to_lower() == "e":
		_advance()
		if _peek() in ["+", "-"]:
			_advance()
		while _digit(_peek()) or _peek() == "_":
			_advance()


func _peek(ahead := 0) -> String:
	return source[offset + ahead] if offset + ahead < source.length() else ""


func _advance() -> void:
	var c := source[offset]
	offset += 1
	if c == "\r":
		if _peek() == "\n":
			offset += 1
		line += 1
		column = 0
	elif c == "\n":
		line += 1
		column = 0
	else:
		column += 1


func _digit(c: String) -> bool:
	return not c.is_empty() and c >= "0" and c <= "9"


func _identifier_start(c: String) -> bool:
	return not c.is_empty() and c.is_valid_identifier()


func _identifier_part(c: String) -> bool:
	return _identifier_start(c) or _digit(c)
