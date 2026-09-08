extends RefCounted
## Editor adapter and dependency-free source formatting API.

const Lexer = preload("syntax/lexer.gd")
const Parser = preload("syntax/parser.gd")
const CstFormatter = preload("format/formatter.gd")
const Printer = preload("format/printer.gd")
const ShaderFormatter = preload("shader_formatter.gd")
const MemberOrganizer = preload("transform/member_organizer.gd")

const ORGANIZE_MEMBERS_SETTING = &"simple_gdscript_formatter/organize_members"


func format(code_edit: CodeEdit) -> String:
	return format_source(code_edit.text, _indentation_for(code_edit))


func format_shader(code_edit: CodeEdit) -> String:
	return format_shader_source(code_edit.text, _indentation_for(code_edit))


func format_source(source: String, indent_text := "\t", line_width := 100) -> String:
	if ProjectSettings.get_setting(ORGANIZE_MEMBERS_SETTING, true):
		source = MemberOrganizer.new().organize(source)
	var lexer = Lexer.new()
	var tokens: Array = lexer.tokenize(source)
	if not lexer.errors.is_empty():
		return source
	var tree = Parser.new().parse(tokens)
	if not tree.errors.is_empty():
		return source
	var document = CstFormatter.new().format_script(tree)
	return Printer.new().print_doc(document, indent_text, line_width)


func format_shader_source(source: String, indent_text := "\t") -> String:
	return ShaderFormatter.new().format_source(source, indent_text)


func _indentation_for(code_edit: CodeEdit) -> String:
	var use_spaces := code_edit.indent_use_spaces
	var indent_size := code_edit.indent_size
	if Engine.is_editor_hint():
		var settings = EditorInterface.get_editor_settings()
		use_spaces = settings.get_setting("text_editor/behavior/indent/type") == 1
		indent_size = settings.get_setting("text_editor/behavior/indent/size")
	return " ".repeat(maxi(1, indent_size)) if use_spaces else "\t"
