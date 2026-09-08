extends RefCounted
## Converts token-referencing CST nodes into layout. Literal and comment text
## is always emitted verbatim. Syntax is supplied by the parser, not rediscovered.

const Cst = preload("../syntax/cst.gd")
const Token = preload("../syntax/token.gd")
const Doc = preload("doc.gd")
const N = Cst.Kind
const K = Token.Kind

var tree
var tokens: Array
var unary: Dictionary = {}
var tight_after: Dictionary = {}


func format_script(syntax_tree):
	tree = syntax_tree
	tokens = tree.tokens
	unary = {}
	tight_after = {}
	if not tree.errors.is_empty():
		return Doc.text(tree.text(0, tokens.size()))
	_collect_roles(tree.root)
	if tree.root.children.is_empty():
		return Doc.text("")
	return Doc.concat([_format_scope(tree.root, true), Doc.line()])


func _collect_roles(node) -> void:
	if node.kind in [N.UNARY_EXPR, N.AWAIT_EXPR]:
		unary[node.attributes.operator] = true
	elif node.kind == N.NODE_PATH_EXPR:
		for i in range(node.first_token, node.last_token - 1):
			tight_after[i] = true
	for child in node.children:
		_collect_roles(child)
	for expression in node.attributes.get("expressions", []):
		_collect_expression_roles(expression)


func _collect_expression_roles(node) -> void:
	if node.kind in [N.UNARY_EXPR, N.AWAIT_EXPR]:
		unary[node.attributes.operator] = true
	elif node.kind == N.NODE_PATH_EXPR:
		for i in range(node.first_token, node.last_token - 1):
			tight_after[i] = true
	# Delimited and lambda nodes are visited through the structural tree.
	if node.attributes.has("open") or node.kind == N.LAMBDA_EXPR:
		return
	for child in node.children:
		_collect_expression_roles(child)


func _format_scope(scope, declarations := false):
	var parts: Array = []
	var previous = null
	for member in scope.children:
		if previous != null:
			var end := _last_content(previous.first_token, previous.last_token)
			var semicolon := false
			for i in range(end + 1, member.first_token):
				if tokens[i].kind == K.SEMICOLON:
					semicolon = true
			if semicolon and tokens[member.first_token].start_line == tokens[end].end_line:
				parts.append(Doc.text(" "))
			else:
				var gap: int = tokens[member.first_token].start_line - tokens[end].end_line
				var blank_lines := mini(1, maxi(0, gap - 1))
				if declarations and (member.kind in [N.FUNCTION_DECL, N.CLASS_DECL] or previous.kind in [N.FUNCTION_DECL, N.CLASS_DECL]):
					blank_lines = 2
				for _i in blank_lines + 1:
					parts.append(Doc.line())
		parts.append(format_declaration(member) if declarations else format_statement(member))
		if member.last_token < tokens.size() and tokens[member.last_token].kind == K.SEMICOLON:
			parts.append(Doc.text(";"))
		previous = member
	return Doc.concat(parts)


func format_declaration(node):
	return _format_member(node)


func format_statement(node):
	return _format_member(node)


func _format_member(node):
	if node.kind == N.COMMENT:
		return Doc.text(tokens[node.first_token].text)
	var end: int = node.attributes.get("header_end", node.last_token)
	var header = _format_sequence(node.first_token, end, node.children, false, node.kind == N.ENUM_DECL)
	if not node.attributes.has("body"):
		return header
	var body = node.attributes.body
	var content = _format_scope(body, node.kind == N.CLASS_DECL)
	if body.attributes.get("inline", false):
		return Doc.concat([header, Doc.text(" "), content])
	return Doc.concat([header, Doc.indent(Doc.concat([Doc.line(), content]))])


func format_expression(node, enum_body := false):
	if node.kind == N.LAMBDA_EXPR:
		return _format_member(node)
	if node.attributes.has("open"):
		return _format_delimited(node, enum_body)
	return _format_sequence(node.first_token, node.last_token, node.children)


func _format_delimited(node, enum_body: bool):
	var open: int = node.attributes.open
	var close: int = node.attributes.get("close", node.last_token)
	if close >= tokens.size():
		return Doc.text(tree.text(node.first_token, node.last_token))
	var last := _last_content(open + 1, close)
	if last < open + 1:
		return Doc.text(tokens[open].text + tokens[close].text)
	var is_brace: bool = tokens[open].kind == K.LEFT_BRACE
	var enum_items: Array = node.attributes.get("expressions", [])
	var multiline_enum := enum_body and enum_items.size() > 1
	var forced: bool = tokens[open].start_line != tokens[close].start_line or multiline_enum
	if enum_body and enum_items.size() == 1 and not _has_comment(open + 1, close):
		forced = false
	var add_comma := -1
	if multiline_enum:
		var code_end := _last_code(open + 1, close)
		if code_end >= 0 and tokens[code_end].kind != K.COMMA:
			add_comma = code_end
	var content = _format_sequence(open + 1, close, node.children, true, false, add_comma)
	var edge := " " if is_brace else ""
	return Doc.group(Doc.concat([
		Doc.text(tokens[open].text),
		Doc.indent(Doc.concat([Doc.soft_line(edge), content])),
		Doc.soft_line(edge), Doc.text(tokens[close].text),
	]), forced)


func _has_comment(first: int, last: int) -> bool:
	for i in range(first, last):
		if tokens[i].kind == K.COMMENT:
			return true
	return false


func _format_sequence(first: int, last: int, structures: Array, delimited := false, enum_body := false, add_comma := -1):
	var indexed := {}
	_index_structures(structures, indexed)
	var parts: Array = []
	var previous := -1
	var pending_newline := false
	var after_comma := false
	var continuation := false
	var continuation_indent := 0
	var i := first
	while i < last:
		var token = tokens[i]
		if token.kind in [K.SPACE, K.TAB]:
			i += 1
			continue
		if token.kind == K.NEWLINE:
			pending_newline = previous >= 0
			if continuation:
				continuation_indent = 2
			i += 1
			continue
		if previous >= 0:
			if enum_body and token.kind == K.LEFT_BRACE and indexed.has(i):
				parts.append(Doc.text(" "))
			elif token.kind == K.COMMENT and not pending_newline:
				parts.append(Doc.text("  "))
			elif pending_newline or tokens[previous].kind == K.COMMENT:
				parts.append(Doc.soft_line() if delimited and tokens[previous].kind != K.COMMENT else Doc.line())
			elif after_comma and delimited:
				parts.append(Doc.soft_line())
			else:
				parts.append(Doc.text(_space_between(previous, i)))
		pending_newline = false
		after_comma = false
		var content
		var end := i + 1
		if indexed.has(i):
			var structure = indexed[i]
			content = format_expression(structure, enum_body and tokens[i].kind == K.LEFT_BRACE)
			end = structure.last_token
		else:
			content = Doc.text(token.text)
			if token.kind == K.BACKSLASH:
				continuation = true
			if token.kind == K.COMMA:
				after_comma = true
		parts.append(Doc.indent(content, continuation_indent) if continuation_indent > 0 else content)
		previous = _last_content(i, end)
		# Lambda suites can own the newline before the next argument. Keep that
		# break when the entire suite is emitted as a single structural child.
		if end > previous + 1 and tokens[end - 1].end_line > tokens[previous].end_line:
			pending_newline = true
		if previous == add_comma:
			parts.append(Doc.text(","))
		i = end
	return Doc.concat(parts)


func _index_structures(children: Array, indexed: Dictionary) -> void:
	for child in children:
		if child.attributes.has("open") or child.kind == N.LAMBDA_EXPR:
			indexed[child.first_token] = child
		elif child.kind in [N.ANNOTATION, N.ANNOTATION_LIST]:
			_index_structures(child.children, indexed)


func _space_between(left: int, right: int) -> String:
	var a = tokens[left]
	var b = tokens[right]
	if b.kind == K.COMMENT:
		return "  "
	if tight_after.has(left):
		return ""
	if b.kind in [K.COMMA, K.COLON, K.SEMICOLON, K.DOT, K.RIGHT_PAREN, K.RIGHT_BRACKET, K.RIGHT_BRACE]:
		return ""
	if a.kind in [K.DOT, K.DOLLAR]:
		return ""
	if unary.has(left) and a.text not in ["not", "await"]:
		# Keep adjacent signs distinct (e.g. '- -x').
		return " " if b.text == a.text and b.text in ["-", "+"] else ""
	if a.kind in [K.LEFT_PAREN, K.LEFT_BRACKET]:
		return ""
	if b.kind in [K.LEFT_PAREN, K.LEFT_BRACKET]:
		if a.kind in [K.IDENTIFIER, K.ANNOTATION, K.SELF, K.SUPER, K.FUNC, K.RIGHT_PAREN, K.RIGHT_BRACKET] or a.kind == K.STRING:
			return ""
	return " "


func _last_content(first: int, last: int) -> int:
	var index := last - 1
	while index >= first and tokens[index].kind in [K.SPACE, K.TAB, K.NEWLINE]:
		index -= 1
	return index


func _last_code(first: int, last: int) -> int:
	var index := last - 1
	while index >= first and tokens[index].is_trivia():
		index -= 1
	return index
