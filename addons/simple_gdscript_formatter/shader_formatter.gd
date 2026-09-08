extends RefCounted
## Lightweight formatter for Godot's GLSL-like shader language.
##
## This intentionally stays separate from the GDScript CST. It changes layout
## around shader tokens while emitting strings, comments, and preprocessor
## directives from their original text.

const OPERATORS: Array[String] = [
	"<<=", ">>=", "++", "--", "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=",
	"==", "!=", "<=", ">=", "&&", "||", "<<", ">>", "->",
	"=", "+", "-", "*", "/", "%", "<", ">", "&", "|", "^", "!", "~",
]
const CONTROL_PAREN_WORDS := ["if", "for", "while", "switch"]
const UNARY_WORDS := ["return", "discard", "case"]
const OPENERS := ["(", "[", "{"]
const CLOSERS := [")", "]", "}"]

var source := ""
var tokens: Array = []
var cursor := 0
var indent_text := "\t"
var indent_level := 0
var paren_depth := 0
var bracket_depth := 0
var lines: Array[String] = []
var current := ""
var pending_newlines := 0
var previous = null


func format_source(code: String, indentation := "\t") -> String:
	source = code
	indent_text = indentation
	tokens = _tokenize(source)
	indent_level = 0
	paren_depth = 0
	bracket_depth = 0
	lines = []
	current = ""
	pending_newlines = 0
	previous = null
	if tokens.is_empty():
		return ""

	for i in tokens.size():
		cursor = i
		var token: Dictionary = tokens[i]
		if token["kind"] == "newline":
			pending_newlines += 1
			continue
		_before_token(token)
		match token["kind"]:
			"word", "number", "string":
				_format_atom(token)
			"operator":
				_format_operator(token["text"])
			"symbol":
				_format_symbol(token["text"])
			"line_comment":
				_format_line_comment(token["text"])
			"block_comment":
				_format_block_comment(token["text"])
			"preprocessor":
				_format_preprocessor(token["text"])
		previous = token

	if not current.is_empty():
		_newline()
	if lines.is_empty():
		return ""
	return "\n".join(lines) + "\n"


func _before_token(token: Dictionary) -> void:
	if pending_newlines <= 0:
		return
	if current.is_empty():
		if pending_newlines > 1 and not lines.is_empty() and lines[-1] != "" and token["text"] != "}":
			lines.append("")
	elif _breaks_at_source_newline(token):
		_newline()
	pending_newlines = 0


func _breaks_at_source_newline(token: Dictionary) -> bool:
	if previous == null or token["kind"] == "line_comment" or token["kind"] not in ["word", "number", "string"] or token["text"] in ["{", "}", ";", ",", ")", "]", "."]:
		return false
	if previous["text"] == "}" and token["text"] == "else":
		return false
	if paren_depth > 0 or bracket_depth > 0:
		return false
	if previous["kind"] == "operator" or previous["text"] in OPENERS or previous["text"] in [",", ".", ":", "?", "return", "discard", "case", "else"]:
		return false
	return true


func _format_atom(token: Dictionary) -> void:
	if previous != null:
		if previous["kind"] in ["word", "number", "string"] or previous["text"] in CLOSERS:
			_space()
		elif previous["kind"] == "block_comment":
			_space()
	_emit(token["text"])


func _format_operator(operator: String) -> void:
	var unary := operator in ["+", "-", "!", "~"] and _is_unary_position()
	if operator in ["++", "--"]:
		if _is_unary_position():
			_emit(operator)
		else:
			_trim_right()
			_emit(operator)
		return
	if unary:
		if previous != null and (previous["kind"] == "operator" or previous["text"] in UNARY_WORDS or previous["text"] in ["?", ":"]):
			_space()
		else:
			_trim_right()
		_emit(operator)
		return
	_space()
	_emit(operator)
	_space()


func _is_unary_position() -> bool:
	if previous == null:
		return true
	return previous["kind"] == "operator" or previous["text"] in ["(", "[", "{", ",", ";", ":", "?", "return", "discard", "case"]


func _format_symbol(symbol: String) -> void:
	match symbol:
		"{":
			_space()
			_emit("{")
			indent_level += 1
			_newline()
		"}":
			if not current.is_empty():
				_newline()
			indent_level = maxi(0, indent_level - 1)
			_emit("}")
			var next_after_brace := _next_significant(cursor + 1)
			if next_after_brace >= tokens.size() or tokens[next_after_brace]["text"] not in ["else", ";", ",", ")", "]"]:
				_newline()
		")":
			_trim_right()
			_emit(")")
			paren_depth = maxi(0, paren_depth - 1)
		"]":
			_trim_right()
			_emit("]")
			bracket_depth = maxi(0, bracket_depth - 1)
		"(":
			if previous != null and previous["kind"] == "word" and previous["text"] in CONTROL_PAREN_WORDS:
				_space()
			_emit("(")
			paren_depth += 1
		"[":
			_emit("[")
			bracket_depth += 1
		",":
			_trim_right()
			_emit(",")
			var next_after_comma := _next_significant(cursor + 1)
			if next_after_comma < tokens.size() and tokens[next_after_comma]["text"] not in CLOSERS:
				_space()
		";":
			_trim_right()
			_emit(";")
			if paren_depth > 0:
				_space()
			else:
				_newline()
		":":
			_trim_right()
			_space()
			_emit(":")
			_space()
		"?":
			_space()
			_emit("?")
			_space()
		".":
			_trim_right()
			_emit(".")
		_:
			_emit(symbol)


func _format_line_comment(comment: String) -> void:
	if not current.is_empty():
		_space()
	_emit(comment)
	_newline()


func _format_block_comment(comment: String) -> void:
	if not comment.contains("\n") and not comment.contains("\r"):
		if not current.is_empty():
			_space()
		_emit(comment)
		return
	if not current.is_empty():
		_newline()
	var parts := comment.replace("\r\n", "\n").replace("\r", "\n").split("\n")
	for i in parts.size():
		if i == 0:
			_emit(parts[i])
		else:
			_newline()
			# Keep the block comment's own interior indentation relative to the
			# current shader block.
			current = indent_text.repeat(indent_level) + parts[i]
	_newline()


func _format_preprocessor(directive: String) -> void:
	if not current.is_empty():
		_newline()
	var saved_indent := indent_level
	indent_level = 0
	_emit(directive)
	indent_level = saved_indent
	_newline()


func _emit(text: String) -> void:
	if text.is_empty():
		return
	if current.is_empty():
		current = indent_text.repeat(indent_level) + text
	else:
		current += text


func _space() -> void:
	if current.is_empty() or current.ends_with(" ") or current.ends_with("\t"):
		return
	current += " "


func _trim_right() -> void:
	while current.ends_with(" ") or current.ends_with("\t"):
		current = current.substr(0, current.length() - 1)


func _newline() -> void:
	_trim_right()
	if not current.is_empty():
		lines.append(current)
		current = ""
	pending_newlines = 0


func _next_significant(index: int) -> int:
	while index < tokens.size() and tokens[index]["kind"] == "newline":
		index += 1
	return index


func _tokenize(code: String) -> Array:
	var result: Array = []
	var index := 0
	var line_start := true
	while index < code.length():
		var character := code[index]
		if character in [" ", "\t"]:
			index += 1
			continue
		if character == "\r" or character == "\n":
			var start := index
			if character == "\r" and index + 1 < code.length() and code[index + 1] == "\n":
				index += 2
			else:
				index += 1
			result.append(_token("newline", code.substr(start, index - start)))
			line_start = true
			continue
		if line_start and character == "#":
			var directive_start := index
			while index < code.length() and code[index] not in ["\r", "\n"]:
				index += 1
			result.append(_token("preprocessor", code.substr(directive_start, index - directive_start)))
			line_start = false
			continue
		if character == "/" and index + 1 < code.length() and code[index + 1] == "/":
			var comment_start := index
			index += 2
			while index < code.length() and code[index] not in ["\r", "\n"]:
				index += 1
			result.append(_token("line_comment", code.substr(comment_start, index - comment_start)))
			line_start = false
			continue
		if character == "/" and index + 1 < code.length() and code[index + 1] == "*":
			var block_start := index
			index += 2
			while index < code.length() and code.substr(index, 2) != "*/":
				index += 1
			if index < code.length():
				index += 2
			result.append(_token("block_comment", code.substr(block_start, index - block_start)))
			line_start = false
			continue
		if character in ["\"", "'"]:
			var string_start := index
			var delimiter := character
			if code.substr(index, 3) == character.repeat(3):
				delimiter = character.repeat(3)
				index += 3
			else:
				index += 1
			while index < code.length():
				if code[index] == "\\":
					index += mini(2, code.length() - index)
				elif code.substr(index, delimiter.length()) == delimiter:
					index += delimiter.length()
					break
				else:
					index += 1
			result.append(_token("string", code.substr(string_start, index - string_start)))
			line_start = false
			continue
		if _is_identifier_start(character):
			var word_start := index
			index += 1
			while index < code.length() and _is_identifier_part(code[index]):
				index += 1
			result.append(_token("word", code.substr(word_start, index - word_start)))
			line_start = false
			continue
		if _is_digit(character) or (character == "." and index + 1 < code.length() and _is_digit(code[index + 1])):
			var number_start := index
			index = _scan_number(code, index)
			result.append(_token("number", code.substr(number_start, index - number_start)))
			line_start = false
			continue
		var operator := ""
		for candidate: String in OPERATORS:
			if code.substr(index, candidate.length()) == candidate:
				operator = candidate
				break
		if not operator.is_empty():
			result.append(_token("operator", operator))
			index += operator.length()
		else:
			result.append(_token("symbol", character))
			index += 1
		line_start = false
	return result


func _scan_number(code: String, start: int) -> int:
	var index := start
	if code[index] == "0" and index + 1 < code.length() and code[index + 1].to_lower() in ["x", "b"]:
		index += 2
		while index < code.length() and (code[index].is_valid_int() or code[index].to_lower() in ["a", "b", "c", "d", "e", "f", "_"]):
			index += 1
		return index
	while index < code.length() and (_is_digit(code[index]) or code[index] == "_"):
		index += 1
	if index < code.length() and code[index] == "." and not (index + 1 < code.length() and code[index + 1] == "."):
		index += 1
		while index < code.length() and (_is_digit(code[index]) or code[index] == "_"):
			index += 1
	if index < code.length() and code[index].to_lower() == "e":
		index += 1
		if index < code.length() and code[index] in ["+", "-"]:
			index += 1
		while index < code.length() and (_is_digit(code[index]) or code[index] == "_"):
			index += 1
	return index


func _token(kind: String, text: String) -> Dictionary:
	return {"kind": kind, "text": text}


func _is_digit(character: String) -> bool:
	return not character.is_empty() and character >= "0" and character <= "9"


func _is_identifier_start(character: String) -> bool:
	return not character.is_empty() and (character == "_" or (character >= "a" and character <= "z") or (character >= "A" and character <= "Z"))


func _is_identifier_part(character: String) -> bool:
	return _is_identifier_start(character) or _is_digit(character)
