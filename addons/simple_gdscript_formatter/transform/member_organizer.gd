extends RefCounted
## Explicit, opt-in transformation: moving initializers can change behavior.
## The normal formatter never calls this module.

const Lexer = preload("../syntax/lexer.gd")
const Parser = preload("../syntax/parser.gd")
const Cst = preload("../syntax/cst.gd")
const Token = preload("../syntax/token.gd")
const N = Cst.Kind

var tree


func organize(source: String) -> String:
	var lexer = Lexer.new()
	tree = Parser.new().parse(lexer.tokenize(source))
	if not lexer.errors.is_empty() or not tree.errors.is_empty():
		return source
	return _scope_text(tree.root, 0, tree.tokens.size())


func category(member) -> int:
	var private_offset := 1 if tree.is_private(member) else 0
	match member.kind:
		N.SIGNAL_DECL:
			return 0
		N.ENUM_DECL:
			return 10
		N.CONSTANT_DECL:
			return 20 + private_offset
		N.VARIABLE_DECL:
			if tree.is_static(member):
				return 30 + private_offset
			for annotation in member.attributes.get("annotations", []):
				if tree.tokens[annotation.first_token].text.begins_with("@export"):
					return 40 + private_offset
			if tree.has_annotation(member, "onready"):
				return 60 + private_offset
			return 50 + private_offset
		N.FUNCTION_DECL:
			var name: String = tree.member_name(member)
			if name == "_static_init":
				return 70
			if tree.is_static(member):
				return 71
			var virtuals := ["_init", "_enter_tree", "_ready", "_process", "_physics_process"]
			if name in virtuals:
				return 72 + virtuals.find(name)
			if name.begins_with("_input") or name.begins_with("_unhandled"):
				return 77
			return 80 + private_offset
		N.CLASS_DECL:
			return 90
	# Headers, unknown syntax, and standalone comments are ordering barriers.
	return -1


func _scope_text(scope, first: int, last: int) -> String:
	if scope.children.is_empty():
		return tree.text(first, last)
	var result: String = tree.text(first, _line_start(scope.children[0].first_token, first))
	var run: Array = []
	for i in scope.children.size():
		var member = scope.children[i]
		var start := _line_start(member.first_token, first)
		var end: int = _line_start(scope.children[i + 1].first_token, first) if i + 1 < scope.children.size() else last
		var content: String = tree.text(start, end)
		if member.kind == N.CLASS_DECL and member.attributes.has("body"):
			var body = member.attributes.body
			content = tree.text(start, body.first_token) + _scope_text(body, body.first_token, body.last_token) + tree.text(body.last_token, end)
		var rank := category(member)
		if rank < 0:
			result += _flush(run) + content
			run.clear()
		else:
			run.append({"rank": rank, "order": i, "text": content})
	return result + _flush(run)


func _flush(run: Array) -> String:
	run.sort_custom(func(a, b): return a.rank < b.rank if a.rank != b.rank else a.order < b.order)
	var result := ""
	for i in run.size():
		result += run[i].text
		if i + 1 < run.size() and not result.ends_with("\n"):
			result += "\n"
	return result


func _line_start(index: int, limit: int) -> int:
	while index > limit and tree.tokens[index - 1].kind in [Token.Kind.SPACE, Token.Kind.TAB]:
		index -= 1
	return index
