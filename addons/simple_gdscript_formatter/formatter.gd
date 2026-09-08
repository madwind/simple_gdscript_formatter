extends RefCounted
## Editor adapter and dependency-free source formatting API.

const Lexer = preload("syntax/lexer.gd")
const Parser = preload("syntax/parser.gd")
const CstFormatter = preload("format/formatter.gd")
const Printer = preload("format/printer.gd")


func format(code_edit: CodeEdit) -> String:
	var use_spaces := code_edit.indent_use_spaces
	var indent_size := code_edit.indent_size
	if Engine.is_editor_hint():
		var settings = EditorInterface.get_editor_settings()
		use_spaces = settings.get_setting("text_editor/behavior/indent/type") == 1
		indent_size = settings.get_setting("text_editor/behavior/indent/size")
	var indentation := " ".repeat(maxi(1, indent_size)) if use_spaces else "\t"
	return format_source(code_edit.text, indentation)


func format_source(source: String, indent_text := "\t", line_width := 100) -> String:
	var lexer = Lexer.new()
	var tokens: Array = lexer.tokenize(source)
	if not lexer.errors.is_empty():
		return source
	var tree = Parser.new().parse(tokens)
	if not tree.errors.is_empty():
		return source
	var document = CstFormatter.new().format_script(tree)
	return Printer.new().print_doc(document, indent_text, line_width)
