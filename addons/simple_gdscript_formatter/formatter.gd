const CodeOrder = preload("rules/code_order.gd")
const Spacing = preload("rules/spacing.gd")
const SyntaxStyle = preload("rules/syntax_style.gd")
const BlankLines = preload("rules/blank_lines.gd")


func format(code_edit: CodeEdit) -> String:
	var code_comment_map = {}
	var comment_map = {}
	var string_map = {}

	var code := code_edit.text
	var line_index := 0
	while line_index < code_edit.get_line_count():
		var line := code_edit.get_line(line_index)
		var column_index := 0
		while column_index < line.length():
			var placeholder := ""
			var map: Dictionary
			var start_line := line_index
			var start_column := column_index
			var end_line: int
			var end_column: int
			if code_edit.is_in_comment(line_index, column_index) > -1:
				if line[column_index] == " ":
					placeholder = "__COMMENT__%d__" % comment_map.keys().size()
					map = comment_map
				else:
					placeholder = "__COMMENT__CODE__%d__" % code_comment_map.keys().size()
					map = code_comment_map
			if code_edit.is_in_string(line_index, column_index) > -1:
				placeholder = "__STRING__%d__" % string_map.keys().size()
				map = string_map
			if placeholder != "":
				var end_position := code_edit.get_delimiter_end_position(line_index, column_index)
				end_line = end_position.y
				end_column = end_position.x
				map[placeholder] = _extrat_text(code_edit, start_line, start_column - 1, end_line, end_column)
				code = _replace(code, map[placeholder], placeholder)
				line_index = end_line
				column_index = end_column
			else:
				column_index += 1
		line_index += 1

	var ref_regex = RegEx.create_from_string(r"\$.*?(?=[.\n]|$)")
	var ref_matches = ref_regex.search_all(code)
	var ref_map = {}

	for i in range(ref_matches.size()):
		var match = ref_matches[i]
		var original = match.get_string()
		var placeholder = "__REF__%d__" % i
		ref_map[placeholder] = original
		code = _replace(code, original, placeholder)

	var breaker_regex = RegEx.create_from_string(r"\\\n\s*")
	var breaker_matches = breaker_regex.search_all(code)
	var breaker_map = {}
	for i in range(breaker_matches.size()):
		var match = breaker_matches[i]
		var original = match.get_string()
		var placeholder = "__BREAKER__%d__" % i
		breaker_map[placeholder] = original
		code = _replace(code, original, placeholder)

	code = _apply_rules(code)

	for placeholder in ref_map:
		code = code.replace(placeholder, ref_map[placeholder])
	for placeholder in comment_map:
		code = code.replace(placeholder, comment_map[placeholder])
	for placeholder in code_comment_map:
		code = code.replace(placeholder, code_comment_map[placeholder])
	for placeholder in string_map:
		code = code.replace(placeholder, string_map[placeholder])
	for placeholder in breaker_map:
		code = code.replace(placeholder, breaker_map[placeholder])

	if code.length() > 0:
		code = code.strip_edges() + "\n"

	return code


func _apply_rules(code: String) -> String:
	code = Spacing.apply(code)

	code = SyntaxStyle.apply(code)
	code = Spacing.apply(code)

	code = CodeOrder.apply(code)
	code = Spacing.apply(code)

	code = BlankLines.apply(code)

	code = _apply_editor_indent_setting(code)

	return code


func _replace(text: String, what: String, forwhat: String) -> String:
	var index := text.find(what)
	if index != -1:
		text = text.substr(0, index) + forwhat + text.substr(index + what.length())
	return text


func _extrat_text(code_edit: CodeEdit, start_line: int, start_column: int, end_line: int, end_column: int) -> String:
	if code_edit.get_line(start_line)[start_column - 1] == "&":
		start_column -= 1
	if start_line == end_line:
		return code_edit.get_line(start_line).substr(start_column, end_column - start_column)
	var text := ""
	if start_column == -1:
		start_line -= 1
		start_column = code_edit.get_line(start_line).length() - 1
	for i in range(start_line, end_line + 1):
		if i == start_line:
			text += code_edit.get_line(start_line).substr(start_column)
		elif i == end_line:
			text += '\n' + code_edit.get_line(end_line).substr(0, end_column)
		else:
			text += '\n' + code_edit.get_line(i)
	return text


func _apply_editor_indent_setting(code: String) -> String:
	var settings = EditorInterface.get_editor_settings()
	var indent_type = settings.get_setting("text_editor/behavior/indent/type")
	if indent_type == 1:
		var indent_size = settings.get_setting("text_editor/behavior/indent/size")
		var indent_str = " ".repeat(indent_size)
		var indent_regex = RegEx.create_from_string(r"\n\t+")
		for m in indent_regex.search_all(code):
			var tab_length = m.get_string().length() - 1
			code = indent_regex.sub(code, "\n" + indent_str.repeat(tab_length))
	return code
