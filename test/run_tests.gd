extends SceneTree

const Lexer = preload("../addons/simple_gdscript_formatter/syntax/lexer.gd")
const Token = preload("../addons/simple_gdscript_formatter/syntax/token.gd")
const Parser = preload("../addons/simple_gdscript_formatter/syntax/parser.gd")
const Cst = preload("../addons/simple_gdscript_formatter/syntax/cst.gd")
const MemberOrganizer = preload("../addons/simple_gdscript_formatter/transform/member_organizer.gd")
const Doc = preload("../addons/simple_gdscript_formatter/format/doc.gd")
const Printer = preload("../addons/simple_gdscript_formatter/format/printer.gd")
const CstFormatter = preload("../addons/simple_gdscript_formatter/format/formatter.gd")
const Formatter = preload("../addons/simple_gdscript_formatter/formatter.gd")

var failures := 0
var checks := 0


func _init() -> void:
	_test_lexer()
	_test_declarations()
	_test_organizer()
	_test_statements()
	_test_expressions()
	_test_printer()
	_test_formatter()
	_test_corpus()
	_test_semantics()
	_test_entry_point()
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


func _test_organizer() -> void:
	var source := "var z := 1\n## docs\n@export\nvar speed := 2\nsignal changed\n# barrier\n\nvar b := 2\nconst A := 1\n"
	var result: String = MemberOrganizer.new().organize(source)
	check(result.begins_with("signal changed\n## docs\n@export\nvar speed := 2\nvar z := 1\n"), "organizer moves annotations and docs as a unit")
	check(result.ends_with("# barrier\n\nconst A := 1\nvar b := 2\n"), "standalone comment is an ordering barrier")
	check(MemberOrganizer.new().organize(result) == result, "organizer is stable")
	result = MemberOrganizer.new().organize("class Inner:\n    var z := [\n        1, 2\n    ]\n    signal changed\n")
	check(result.begins_with("class Inner:\n    signal changed\n    var z"), "organizer handles nested classes and multiline declarations")


func _test_statements() -> void:
	var tree = parse("func run():\n    if value:\n        for item in items:\n            while item:\n                break\n    elif other:\n        return 1\n    else:\n        pass\n    match value:\n        1:\n            foo()\n        2, 3 when ok:\n            continue\n        _:\n            pass\n    if value: pass; foo()\n")
	var body = tree.root.children[0].attributes.body
	check(body.kind == Cst.Kind.BLOCK and body.children.size() == 5, "function statement block")
	var loop = body.children[0].attributes.body.children[0]
	check(loop.kind == Cst.Kind.FOR_STMT, "nested for statement")
	check(loop.attributes.body.children[0].kind == Cst.Kind.WHILE_STMT, "nested while statement")
	check(body.children[1].kind == Cst.Kind.ELIF_CLAUSE and body.children[2].kind == Cst.Kind.ELSE_CLAUSE, "elif and else clauses")
	var branches = body.children[3].attributes.body.children
	check(branches.size() == 3 and branches[1].kind == Cst.Kind.MATCH_BRANCH, "match branches are structural")
	check(body.children[4].attributes.body.children.size() == 2, "inline suite with semicolons")


func expression(source: String):
	return parse(source).root.children[0].attributes.expressions[0]


func _test_expressions() -> void:
	var node = expression("a + b * c")
	check(node.kind == Cst.Kind.BINARY_EXPR and node.children[1].kind == Cst.Kind.BINARY_EXPR, "multiplication binds before addition")
	check(expression("-2 ** 2").kind == Cst.Kind.UNARY_EXPR, "power binds before unary sign")
	node = expression("a ** b ** c")
	check(node.children[0].kind == Cst.Kind.BINARY_EXPR, "power is left-associative in GDScript")
	node = expression("not a in b and c")
	check(node.children[0].kind == Cst.Kind.UNARY_EXPR, "not binds below membership and above and")
	node = expression("foo.bar[index](a + b)")
	check(node.kind == Cst.Kind.CALL_EXPR and node.children[0].kind == Cst.Kind.SUBSCRIPT_EXPR, "call and subscript chain")
	check(node.children[0].children[0].kind == Cst.Kind.MEMBER_EXPR, "member access")
	check(expression("x = y + z").kind == Cst.Kind.ASSIGNMENT_EXPR, "assignment")
	check(expression("x if condition else y").kind == Cst.Kind.CONDITIONAL_EXPR, "conditional expression")
	check(expression("x as Node").kind == Cst.Kind.CAST_EXPR, "cast")
	check(expression("x is Node").kind == Cst.Kind.TYPE_CHECK_EXPR, "type check")
	node = expression("x as Node == y")
	check(node.kind == Cst.Kind.BINARY_EXPR and node.children[0].kind == Cst.Kind.CAST_EXPR, "cast consumes only the type name")
	node = expression("x is not Node and y")
	check(node.kind == Cst.Kind.BINARY_EXPR and node.children[0].attributes.negated, "negated type test precedes logical and")
	check(expression("await foo()").kind == Cst.Kind.AWAIT_EXPR, "await")
	check(expression("[1, {\"key\": [2, 3]}]").kind == Cst.Kind.ARRAY_EXPR, "nested containers")
	var tree = parse("sig.connect(\n    func() -> void:\n        sig.connect(func():\n            if value:\n                foo()\n        )\n        match value:\n            _:\n                pass\n)\nvar callback := func(value: int) -> void:\n    print(value)\nvar after := 1\n")
	check(tree.root.children.size() == 3, "lambda does not consume next declaration")
	node = tree.root.children[0].attributes.expressions[0].children[1].children[0]
	check(node.kind == Cst.Kind.LAMBDA_EXPR and node.attributes.body.children.size() == 2, "lambda has a statement block")
	var nested = node.attributes.body.children[0].attributes.expressions[0].children[1].children[0]
	check(nested.kind == Cst.Kind.LAMBDA_EXPR and nested.attributes.body.children[0].kind == Cst.Kind.IF_STMT, "nested lambda statements")


func _test_printer() -> void:
	var document = Doc.group(Doc.concat([
		Doc.text("foo("),
		Doc.indent(Doc.concat([Doc.soft_line(""), Doc.text("alpha,"), Doc.soft_line(), Doc.text("beta")])),
		Doc.soft_line(""), Doc.text(")"),
	]))
	var printer = Printer.new()
	check(printer.print_doc(document) == "foo(alpha, beta)", "group flattens")
	check(printer.print_doc(document, "  ", 10) == "foo(\n  alpha,\n  beta\n)", "group expands and indents")
	check(printer.print_doc(document) == printer.print_doc(document), "printer is deterministic")
	check(printer.print_doc(Doc.indent(Doc.concat([Doc.text("a"), Doc.line(), Doc.line(), Doc.text("b")])), "  ") == "  a\n\n  b", "blank lines have no indentation")


func format_source(source: String, indent_text := "\t", width := 100) -> String:
	return Printer.new().print_doc(CstFormatter.new().format_script(parse(source)), indent_text, width)


func significant_tokens(source: String) -> Array:
	var result: Array = []
	var tree = parse(source)
	var ignored := {}
	_optional_enum_commas(tree.root, tree.tokens, ignored)
	for i in tree.tokens.size():
		var token = tree.tokens[i]
		if token.kind not in [Token.Kind.SPACE, Token.Kind.TAB, Token.Kind.NEWLINE] and not ignored.has(i):
			result.append(token.text)
	return result


func _optional_enum_commas(node, stream: Array, ignored: Dictionary) -> void:
	if node.kind == Cst.Kind.ENUM_DECL:
		for child in node.children:
			if child.attributes.has("close"):
				var last: int = child.attributes.close - 1
				while last > child.first_token and stream[last].is_trivia():
					last -= 1
				if stream[last].kind == Token.Kind.COMMA:
					ignored[last] = true
	for child in node.children:
		_optional_enum_commas(child, stream, ignored)


func _test_formatter() -> void:
	var samples: Array[String] = [
		FileAccess.get_file_as_string("res://test/test.gd"),
		"@export var a=1\n@export\nvar b=2\nvar p:=1.0## a comment with a '\nvar c:=&\"ab\"\nvar n:=^\"..\"\n",
		"func run():\n            if a:\n                while b:\n                    pass\n",
		"var a := '''\n  # untouched\n\t'''\nvar b := \"\"\"a\r\nb\"\"\"\n",
		"var a=$Node/Child\nvar b=1-%Unique.num\nvar c=1%3+1\nvar d=- 2 ** 2\n",
		"var x = [1 ,2,\n3]\nvar y = {\"key\": [1,2], \"other\": 2}\n",
		"enum State {A,B,C}\nfunc run():\n    match 1:\n        1,2: pass\n        _: return\n",
		"sig.connect(func():\n        sig.connect(func():\n            if true:\n                pass\n        )\n)\n",
		"func run():\n    var a = 1 + \\\n        2\n    if true: pass; print(a)\n",
		"var a=1;\nvar b=2; var c=3;\nfunc f(): pass;\n",
		"var pattern = r\"\\d+\"\nvar x = [1, # comment\n2, # last\n]\n",
		"@export # inline\n# between annotation and declaration\nvar value=1\n",
	]
	for i in samples.size():
		var source := samples[i]
		var result := format_source(source)
		var twice := format_source(result)
		check(result == twice, "formatter idempotence sample %d" % i)
		if result != twice:
			FileAccess.open("res://test/first.tmp", FileAccess.WRITE).store_string(result)
			FileAccess.open("res://test/second.tmp", FileAccess.WRITE).store_string(twice)
		check(significant_tokens(source) == significant_tokens(result), "tokens and declaration order preserved sample %d" % i)
		check(parse(result).errors.is_empty(), "formatted source parses sample %d" % i)
	check(format_source("var a=1+2*3\n") == "var a = 1 + 2 * 3\n", "operator spacing")
	check(format_source("func run():\n        pass\n", "  ") == "func run():\n  pass\n", "indentation follows CST and preference")
	check(format_source("var n=$Node/Child\n") == "var n = $Node/Child\n", "node path is not divided")
	check(format_source("var n=1-%Unique.num\n") == "var n = 1 - %Unique.num\n", "unique-node prefix versus binary modulo")
	check(format_source("var d={key=1}\n") == "var d = { key = 1 }\n", "dictionary style")


func _test_corpus() -> void:
	var paths: Array[String] = ["res://test/test.gd", "res://test/fixtures/semantics.gd"]
	_collect_scripts("res://addons/simple_gdscript_formatter", paths)
	for path in paths:
		var source := FileAccess.get_file_as_string(path)
		var result := format_source(source)
		check(format_source(result) == result, "corpus idempotence: " + path)
		if format_source(result) != result:
			var debug_name := path.trim_prefix("res://").replace("/", "_")
			FileAccess.open("res://test/" + debug_name + ".first.tmp", FileAccess.WRITE).store_string(result)
			FileAccess.open("res://test/" + debug_name + ".second.tmp", FileAccess.WRITE).store_string(format_source(result))
		check(significant_tokens(source) == significant_tokens(result), "corpus tokens: " + path)
		var script := GDScript.new()
		script.resource_path = path + ".formatted.gd"
		script.source_code = result
		check(script.reload() == OK, "Godot compiles formatted source: " + path)
		if path == "res://test/test.gd" and "--update-golden" in OS.get_cmdline_user_args():
			FileAccess.open("res://test/result.gd", FileAccess.WRITE).store_string(result)
	check(format_source(FileAccess.get_file_as_string("res://test/test.gd")) == FileAccess.get_file_as_string("res://test/result.gd"), "golden fixture")


func _collect_scripts(directory: String, paths: Array[String]) -> void:
	for file in DirAccess.get_files_at(directory):
		if file.ends_with(".gd"):
			paths.append(directory.path_join(file))
	for child in DirAccess.get_directories_at(directory):
		_collect_scripts(directory.path_join(child), paths)


func _test_semantics() -> void:
	var source := FileAccess.get_file_as_string("res://test/fixtures/semantics.gd")
	var original := GDScript.new()
	original.source_code = source
	check(original.reload() == OK, "semantic fixture compiles before formatting")
	var expected: Array = original.new().evaluate()
	for indentation in ["\t", "  ", "    "]:
		var formatted := GDScript.new()
		formatted.source_code = format_source(source, indentation, 60)
		check(formatted.reload() == OK, "semantic fixture compiles after formatting")
		check(formatted.new().evaluate() == expected, "runtime behavior and initializer order are unchanged")
		check(format_source(formatted.source_code, indentation, 60) == formatted.source_code, "narrow layout is idempotent")
		if format_source(formatted.source_code, indentation, 60) != formatted.source_code:
			FileAccess.open("res://test/narrow.first.tmp", FileAccess.WRITE).store_string(formatted.source_code)
			FileAccess.open("res://test/narrow.second.tmp", FileAccess.WRITE).store_string(format_source(formatted.source_code, indentation, 60))


func _test_entry_point() -> void:
	var formatter = Formatter.new()
	var source := "var second=2\nvar first=1\nfunc run():\n    pass\n"
	check(formatter.format_source(source) == format_source(source), "public API uses CST pipeline")
	var editor := CodeEdit.new()
	editor.text = source
	editor.indent_use_spaces = true
	editor.indent_size = 2
	check(formatter.format(editor) == format_source(source, "  "), "CodeEdit space indentation")
	editor.indent_use_spaces = false
	check(formatter.format(editor) == format_source(source, "\t"), "CodeEdit tab indentation")
	editor.free()
	for incomplete in ["var a = [1,\n", "var a=\"unterminated", "var a = (1]\n", ")\nvar a=1\n"]:
		check(formatter.format_source(incomplete) == incomplete, "incomplete input is preserved")
	check(formatter.format_source(" \n\t") == "", "empty input")
