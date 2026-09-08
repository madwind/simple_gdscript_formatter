extends RefCounted
## Recursive descent over a lossless token stream. Unknown syntax is retained.

const Token = preload("token.gd")
const Cst = preload("cst.gd")
const K = Token.Kind
const N = Cst.Kind
const DECLARATIONS = {
	K.CLASS_NAME: N.CLASS_NAME_DECL, K.EXTENDS: N.EXTENDS_DECL,
	K.CLASS: N.CLASS_DECL, K.VAR: N.VARIABLE_DECL, K.CONST: N.CONSTANT_DECL,
	K.SIGNAL: N.SIGNAL_DECL, K.ENUM: N.ENUM_DECL, K.FUNC: N.FUNCTION_DECL,
}
const CLOSE = {K.LEFT_PAREN: K.RIGHT_PAREN, K.LEFT_BRACKET: K.RIGHT_BRACKET, K.LEFT_BRACE: K.RIGHT_BRACE}
const STATEMENTS = {
	K.IF: N.IF_STMT, K.ELIF: N.ELIF_CLAUSE, K.ELSE: N.ELSE_CLAUSE,
	K.FOR: N.FOR_STMT, K.WHILE: N.WHILE_STMT, K.MATCH: N.MATCH_STMT,
	K.RETURN: N.RETURN_STMT, K.BREAK: N.BREAK_STMT,
	K.CONTINUE: N.CONTINUE_STMT, K.PASS: N.PASS_STMT,
}
const SUITES = [N.IF_STMT, N.ELIF_CLAUSE, N.ELSE_CLAUSE, N.FOR_STMT,
	N.WHILE_STMT, N.MATCH_STMT, N.MATCH_BRANCH, N.FUNCTION_DECL, N.CLASS_DECL]

var tree
var tokens: Array
var cursor := 0


func parse(stream: Array):
	tree = Cst.new()
	tree.tokens = stream
	tokens = stream
	cursor = 0
	tree.root = _parse_scope(-1, N.SCRIPT)
	tree.root.first_token = 0
	tree.root.last_token = tokens.size()
	return tree


func _parse_scope(parent_indent: int, kind: int, match_branches := false):
	var block = Cst.CstNode.new(kind, cursor)
	while cursor < tokens.size():
		_skip_whitespace()
		if _kind() == K.SEMICOLON:
			cursor += 1
			continue
		if cursor >= tokens.size() or _kind() in CLOSE.values():
			break
		if _kind() != K.COMMENT and _indent(cursor) <= parent_indent:
			break
		if _kind() == K.COMMENT:
			# Comment indentation cannot open or close a language block. A comment
			# before a dedent belongs to the outer scope when aligned with it.
			var next := _next_code(cursor)
			if _indent(cursor) <= parent_indent and (next >= tokens.size() or _indent(next) <= parent_indent):
				break
			var comment = Cst.CstNode.new(N.COMMENT, cursor, cursor + 1)
			block.children.append(comment)
			cursor += 1
			continue
		var before := cursor
		var member = _parse_item(N.MATCH_BRANCH if match_branches else -1)
		_attach_comments(block, member)
		block.children.append(member)
		if cursor <= before:
			tree.errors.append("Parser made no progress at token %d" % cursor)
			cursor += 1
	block.last_token = cursor
	return block


func _parse_item(forced_kind := -1):
	var start := cursor
	var indentation := _indent(start)
	var annotations: Array = []
	while _kind() == K.ANNOTATION:
		var annotation = Cst.CstNode.new(N.ANNOTATION, cursor)
		cursor += 1
		_skip_horizontal()
		if _kind() == K.LEFT_PAREN:
			annotation.children.append(_parse_delimited())
		annotation.last_token = cursor
		annotations.append(annotation)
		_skip_whitespace()
	var keyword := cursor
	var static_member := _kind() == K.STATIC
	if static_member:
		cursor += 1
		_skip_horizontal()
		keyword = cursor
	var kind: int = DECLARATIONS.get(_kind(), STATEMENTS.get(_kind(), N.EXPRESSION_STMT))
	if forced_kind >= 0:
		kind = forced_kind
	var member = Cst.CstNode.new(kind, start)
	member.attributes["keyword"] = keyword
	member.attributes["indent"] = indentation
	member.attributes["static"] = static_member
	member.attributes["annotations"] = annotations
	if not annotations.is_empty():
		var annotation_list = Cst.CstNode.new(N.ANNOTATION_LIST, start, annotations[-1].last_token)
		annotation_list.children = annotations
		member.children.append(annotation_list)
	if keyword < tokens.size() and _kind() in DECLARATIONS:
		var name := _next_significant(keyword + 1)
		if name < tokens.size() and tokens[name].kind == K.IDENTIFIER:
			member.attributes["name_token"] = name
	_read_header(member)
	# GDScript permits the enum brace on the next physical line.
	if kind == N.ENUM_DECL:
		var next := _next_significant(cursor)
		if next < tokens.size() and tokens[next].kind == K.LEFT_BRACE:
			cursor = next
			member.children.append(_parse_delimited())
			_read_header(member)
	member.attributes["header_end"] = cursor
	var last := _previous_significant(cursor - 1)
	if last >= keyword and tokens[last].kind == K.COLON:
		_skip_horizontal()
		if _kind() not in [-1, K.NEWLINE, K.COMMENT]:
			var body = Cst.CstNode.new(N.BLOCK, cursor)
			body.attributes["inline"] = true
			while _kind() not in [-1, K.NEWLINE, K.COMMENT] and _kind() not in CLOSE.values():
				body.children.append(_parse_item())
				if _kind() != K.SEMICOLON:
					break
				cursor += 1
				_skip_horizontal()
			body.last_token = cursor
			member.children.append(body)
			member.attributes["body"] = body
			member.last_token = cursor
			return member
		if _kind() == K.COMMENT:
			cursor += 1
		member.attributes["header_end"] = cursor
		var next := _next_code(cursor)
		if next < tokens.size() and _indent(next) > indentation:
			var body = _parse_scope(indentation, N.BLOCK, kind == N.MATCH_STMT)
			member.children.append(body)
			member.attributes["body"] = body
	member.last_token = cursor
	return member


func _read_header(member) -> void:
	var saw_in := false
	while cursor < tokens.size() and _kind() not in [K.NEWLINE, K.SEMICOLON] and _kind() not in CLOSE.values():
		if _kind() in CLOSE:
			member.children.append(_parse_delimited())
		elif _kind() == K.COLON and member.kind in SUITES and (member.kind != N.FOR_STMT or saw_in):
			member.attributes["colon"] = cursor
			cursor += 1
			return
		elif _kind() == K.BACKSLASH:
			cursor += 1
			_skip_horizontal()
			if _kind() == K.NEWLINE:
				cursor += 1
		else:
			if _kind() == K.IN:
				saw_in = true
			cursor += 1


func _parse_delimited():
	var closing: int = CLOSE[_kind()]
	var node = Cst.CstNode.new(N.DELIMITED, cursor)
	node.attributes["open"] = cursor
	cursor += 1
	while cursor < tokens.size() and _kind() != closing:
		if _kind() in CLOSE:
			node.children.append(_parse_delimited())
		elif _kind() in CLOSE.values():
			tree.errors.append("Mismatched delimiter at token %d" % cursor)
			break
		else:
			cursor += 1
	if _kind() == closing:
		node.attributes["close"] = cursor
		cursor += 1
	else:
		tree.errors.append("Unclosed delimiter at token %d" % node.first_token)
	node.last_token = cursor
	return node


func _attach_comments(block, member) -> void:
	var leading: Array = []
	var next_line: int = tokens[member.first_token].start_line
	while not block.children.is_empty():
		var previous = block.children[-1]
		if previous.kind != N.COMMENT:
			break
		var token = tokens[previous.first_token]
		if token.end_line + 1 != next_line or _indent(previous.first_token) != member.attributes.indent:
			break
		leading.push_front(block.children.pop_back())
		next_line = token.start_line
	if not leading.is_empty():
		member.first_token = leading[0].first_token
		member.attributes["leading_comments"] = leading
		member.children = leading + member.children


func _kind() -> int:
	return tokens[cursor].kind if cursor < tokens.size() else -1


func _skip_horizontal() -> void:
	while _kind() in [K.SPACE, K.TAB]:
		cursor += 1


func _skip_whitespace() -> void:
	while _kind() in [K.SPACE, K.TAB, K.NEWLINE]:
		cursor += 1


func _next_significant(index: int) -> int:
	while index < tokens.size() and tokens[index].is_trivia():
		index += 1
	return index


func _next_code(index: int) -> int:
	return _next_significant(index)


func _previous_significant(index: int) -> int:
	while index >= 0 and tokens[index].is_trivia():
		index -= 1
	return index


func _indent(index: int) -> int:
	var line_number: int = tokens[index].start_line
	while index > 0 and tokens[index - 1].start_line == line_number:
		index -= 1
	var width := 0
	while index < tokens.size():
		if tokens[index].kind == K.SPACE:
			width += tokens[index].text.length()
		elif tokens[index].kind == K.TAB:
			width += 4 * tokens[index].text.length()
		else:
			break
		index += 1
	return width
