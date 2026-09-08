extends SceneTree

const Lexer = preload("../addons/simple_gdscript_formatter/syntax/lexer.gd")
const Token = preload("../addons/simple_gdscript_formatter/syntax/token.gd")
const Parser = preload("../addons/simple_gdscript_formatter/syntax/parser.gd")
const Cst = preload("../addons/simple_gdscript_formatter/syntax/cst.gd")

var failures := 0
var checks := 0


func _init() -> void:
	_test_lexer()
	_test_declarations()
	print("Formatter tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _test_lexer() -> void:
	var samples: Array[String] = [
		FileAccess.get_file_as_string("res://test/test.gd"),
		"", "\r\n\t # comment\rnext\n", "var 名称 := 0xFF + 0b10 + 1.2e-3\n",
		"&\"name\" ^'../Node' $Node/Child %UniqueNode # comment\n## docs\n",
		"\"escaped \\\" quote\" '''a\n# string\n''' \"\"\"more\ntext\"\"\"",
		"var incomplete = \"unclosed\n", "a**=2; b<<=1; c:=.5; d=1..2",
	]
	for source in samples:
		var lexer = Lexer.new()
		var tokens: Array = lexer.tokenize(source)
		var joined := ""
		var offset := 0
		for token in tokens:
			check(token.start_offset == offset, "contiguous token offsets")
			check(source.substr(token.start_offset, token.end_offset - token.start_offset) == token.text, "token source range")
			joined += token.text
			offset = token.end_offset
		check(joined == source, "lossless lexer round trip")
	var tokens: Array = Lexer.new().tokenize("a\r\n\tb\n")
	check(tokens[1].text == "\r\n" and tokens[1].end_line == 1, "CRLF is one newline")
	check(tokens[3].start_line == 1 and tokens[3].start_column == 1, "line and column positions")
	check(Lexer.new().tokenize("&\"hi\"")[0].kind == Token.Kind.STRING, "StringName is one string token")


func parse(source: String):
	return Parser.new().parse(Lexer.new().tokenize(source))


func _test_declarations() -> void:
	var source := FileAccess.get_file_as_string("res://test/test.gd")
	var tree = parse(source)
	check(tree.errors.is_empty(), "fixture parses without delimiter errors")
	check(tree.text(0, tree.tokens.size()) == source, "CST retains the source")
	var names: Array = []
	for member in tree.root.children:
		names.append(tree.member_name(member))
	check(names.has("State2") and names.has("test_misc"), "multiline enum boundary")
	check(names.has("node_path") and names.has("run_all_ops"), "top-level members after multiline bodies")
	tree = parse("## docs\n@export_range(\n  0, 1\n)\nvar speed: float = 1\nclass Inner:\n    var value := foo(\n        1, 2\n    )\n    func run():\n        pass\nvar after := 2\n")
	check(tree.root.children.size() == 3, "declarations separated")
	var variable = tree.root.children[0]
	check(tree.has_annotation(variable, "export_range"), "annotation belongs to variable")
	check(tree.tokens[variable.first_token].text == "## docs", "documentation belongs to variable")
	var inner = tree.root.children[1]
	check(inner.kind == Cst.Kind.CLASS_DECL, "nested class kind")
	check(inner.attributes.body.children.size() == 2, "nested class members")
