extends RefCounted
## Pratt parsing over CST token ranges. Delimited nodes and lambda suites have
## already been recognized by recursive descent; no source rescanning is needed.

const Cst = preload("cst.gd")
const Token = preload("token.gd")
const N = Cst.Kind
const K = Token.Kind
# Matches Godot 4.6 GDScriptParser::Precedence. Power is left-associative.
const PRECEDENCE = {
	"=": 1, ":=": 1, "+=": 1, "-=": 1, "*=": 1, "/=": 1, "%=": 1,
	"**=": 1, "<<=": 1, ">>=": 1, "&=": 1, "|=": 1, "^=": 1,
	"as": 2, "if": 3, "or": 4, "||": 4, "and": 5, "&&": 5,
	"in": 7, "not": 7, "==": 8, "!=": 8, "<": 8, ">": 8, "<=": 8, ">=": 8,
	"|": 9, "^": 10, "&": 11, "<<": 12, ">>": 12, "+": 13, "-": 13,
	"*": 14, "/": 14, "%": 14, "**": 17, "is": 18,
}

var tree
var tokens: Array
var atoms: Array = []
var position := 0


func annotate(syntax_tree) -> void:
	tree = syntax_tree
	tokens = tree.tokens
	_annotate_node(tree.root)


func _annotate_node(node) -> void:
	for child in node.children:
		_annotate_node(child)
	if node.kind in [N.SCRIPT, N.BLOCK, N.OPAQUE_BLOCK, N.COMMENT, N.ANNOTATION_LIST]:
		return
	var first: int = node.attributes.get("keyword", node.first_token)
	var last: int = node.attributes.get("header_end", node.last_token)
	if node.attributes.has("open"):
		first = node.attributes.open + 1
		last = node.attributes.get("close", node.last_token)
		match tokens[node.attributes.open].kind:
			K.LEFT_PAREN:
				node.kind = N.PARENTHESIZED_EXPR
			K.LEFT_BRACKET:
				node.kind = N.ARRAY_EXPR
			K.LEFT_BRACE:
				node.kind = N.DICTIONARY_EXPR
	elif node.kind not in [N.EXPRESSION_STMT, N.MATCH_BRANCH]:
		first += 1
	if node.attributes.has("colon"):
		last = node.attributes.colon
	node.attributes["expressions"] = parse_range(first, last, node.children)
	if node.kind in [N.VARIABLE_DECL, N.CONSTANT_DECL]:
		var assignment := _top_level_token(first, last, node.children, ["=", ":="])
		var colon := _top_level_token(first, last, node.children, [":"])
		if assignment >= 0:
			node.attributes["assignment"] = assignment
			node.attributes["initializer"] = parse_range(assignment + 1, last, node.children)
		if colon >= 0 and (assignment < 0 or colon < assignment):
			node.attributes["type"] = parse_range(colon + 1, assignment if assignment >= 0 else last, node.children)


func _top_level_token(first: int, last: int, structures: Array, texts: Array) -> int:
	var ends := {}
	for child in structures:
		ends[child.first_token] = child.last_token
	var i := first
	while i < last:
		if ends.has(i):
			i = maxi(i + 1, ends[i])
		elif tokens[i].text in texts:
			return i
		else:
			i += 1
	return -1


func parse_range(first: int, last: int, structures: Array) -> Array:
	var saved_atoms := atoms
	var saved_position := position
	atoms = []
	position = 0
	var indexed := {}
	for child in structures:
		if child.attributes.has("open") or child.kind == N.LAMBDA_EXPR:
			indexed[child.first_token] = child
	var i := first
	while i < last:
		if indexed.has(i):
			atoms.append(indexed[i])
			i = indexed[i].last_token
		elif tokens[i].is_trivia() or tokens[i].kind == K.BACKSLASH:
			i += 1
		else:
			atoms.append(i)
			i += 1
	var result: Array = []
	while position < atoms.size():
		var before := position
		if _text() in [",", ";", ":", "->", "when", "else"]:
			position += 1
			continue
		var value = _expression(0)
		if _text() == ":":
			var colon := _index()
			position += 1
			var right = _expression(0)
			value = _node(N.PAIR_EXPR, value.first_token, right.last_token, [value, right], colon)
		result.append(value)
		if before == position:
			position += 1
	atoms = saved_atoms
	position = saved_position
	return result


func _expression(minimum: int):
	var left = _prefix()
	while position < atoms.size():
		var atom = atoms[position]
		if not atom is int and atom.attributes.has("open"):
			var open: int = tokens[atom.attributes.open].kind
			if open in [K.LEFT_PAREN, K.LEFT_BRACKET]:
				if 20 < minimum:
					break
				position += 1
				left = _node(N.CALL_EXPR if open == K.LEFT_PAREN else N.SUBSCRIPT_EXPR, left.first_token, atom.last_token, [left, atom])
				continue
		if _text() == "." and 21 >= minimum:
			var operator := _index()
			position += 1
			var right = _prefix()
			left = _node(N.MEMBER_EXPR, left.first_token, right.last_token, [left, right], operator)
			continue
		var op := _text()
		var precedence: int = PRECEDENCE.get(op, -1)
		if precedence < minimum or precedence < 0:
			break
		if op == "not" and _text(1) != "in":
			break
		var operator := _index()
		position += 1
		if op == "not":
			position += 1
		if op == "if":
			var condition = _expression(4)
			if _text() != "else":
				left = _node(N.OPAQUE_EXPRESSION, left.first_token, condition.last_token, [left, condition])
				continue
			position += 1
			var alternative = _expression(3)
			left = _node(N.CONDITIONAL_EXPR, left.first_token, alternative.last_token, [left, condition, alternative], operator)
			continue
		var right = _expression(precedence if precedence == 1 else precedence + 1)
		var kind := N.BINARY_EXPR
		if precedence == 1:
			kind = N.ASSIGNMENT_EXPR
		elif op == "as":
			kind = N.CAST_EXPR
		elif op == "is":
			kind = N.TYPE_CHECK_EXPR
		left = _node(kind, left.first_token, right.last_token, [left, right], operator)
	return left


func _prefix():
	if position >= atoms.size():
		var end: int = tokens.size()
		return _node(N.OPAQUE_EXPRESSION, end, end)
	var atom = atoms[position]
	position += 1
	if not atom is int:
		return atom
	var token = tokens[atom]
	if token.text in ["+", "-", "~", "!", "not", "await"]:
		var precedence := 15
		if token.text in ["not", "!"]:
			precedence = 6
		elif token.text == "~":
			precedence = 16
		elif token.text == "await":
			precedence = 19
		var operand = _expression(precedence)
		return _node(N.AWAIT_EXPR if token.text == "await" else N.UNARY_EXPR, atom, operand.last_token, [operand], atom)
	if token.kind in [K.DOLLAR, K.PERCENT]:
		# Bare node paths are lexical paths; '/' here is not division.
		var end: int = atom + 1
		while position < atoms.size() and atoms[position] is int:
			var index: int = atoms[position]
			if tokens[index].kind not in [K.IDENTIFIER, K.STRING] and tokens[index].text != "/":
				break
			if index != end:
				break
			end = index + 1
			position += 1
		return _node(N.NODE_PATH_EXPR, atom, end)
	var kind := N.IDENTIFIER_EXPR
	if token.kind in [K.NUMBER, K.STRING, K.TRUE, K.FALSE, K.NULL]:
		kind = N.LITERAL_EXPR
	return _node(kind, atom, atom + 1)


func _node(kind: int, first: int, last: int, children: Array = [], operator := -1):
	var node = Cst.CstNode.new(kind, first, last)
	node.children = children
	if operator >= 0:
		node.attributes["operator"] = operator
	return node


func _text(ahead := 0) -> String:
	var index := _index(ahead)
	return tokens[index].text if index >= 0 else ""


func _index(ahead := 0) -> int:
	if position + ahead >= atoms.size() or not atoms[position + ahead] is int:
		return -1
	return atoms[position + ahead]
