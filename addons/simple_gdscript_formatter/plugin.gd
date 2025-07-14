@tool
extends EditorPlugin

const FORMAT_ACTION = &"simple_gdscript_formatter/format"
const OPEN_EXTERNAL_ACTION = &"simple_gdscript_formatter/open_in_external_editor"
var format_key: InputEventKey
var open_external_key: InputEventKey


func _enter_tree():
	add_tool_menu_item("Format GDScript", _on_format_code)
	if InputMap.has_action(FORMAT_ACTION):
		InputMap.erase_action(FORMAT_ACTION)
	InputMap.add_action(FORMAT_ACTION)

	format_key = InputEventKey.new()
	format_key.keycode = KEY_L
	format_key.ctrl_pressed = true
	format_key.alt_pressed = true
	InputMap.action_add_event(FORMAT_ACTION, format_key)

	add_tool_menu_item("Open In External Editor", _open_external)
	if InputMap.has_action(OPEN_EXTERNAL_ACTION):
		InputMap.erase_action(OPEN_EXTERNAL_ACTION)
	InputMap.add_action(OPEN_EXTERNAL_ACTION)

	open_external_key = InputEventKey.new()
	open_external_key.keycode = KEY_E
	open_external_key.ctrl_pressed = true
	InputMap.action_add_event(OPEN_EXTERNAL_ACTION, open_external_key)


func _exit_tree():
	remove_tool_menu_item("Format GDScript")
	InputMap.erase_action(FORMAT_ACTION)
	remove_tool_menu_item("Open In External Editor")
	InputMap.erase_action(OPEN_EXTERNAL_ACTION)


func _on_format_code():
	var current_editor := EditorInterface.get_script_editor().get_current_editor()
	if current_editor and current_editor.is_class("ScriptTextEditor"):
		var code_edit := current_editor.get_base_editor() as CodeEdit
		var code = code_edit.text
		var formatter = preload("formatter.gd").new()
		var formatted_code = formatter.format(code_edit)
		if formatted_code && code != formatted_code:
			var scroll_horizontal = code_edit.scroll_horizontal
			var scroll_vertical = code_edit.scroll_vertical
			var caret_column = code_edit.get_caret_column(0)
			var caret_line = code_edit.get_caret_line(0)
			code_edit.text = formatted_code
			code_edit.set_caret_line(caret_line)
			code_edit.set_caret_column(caret_column)
			code_edit.do_indent()
			code_edit.undo()
			code_edit.scroll_horizontal = scroll_horizontal
			code_edit.scroll_vertical = scroll_vertical


func _open_external() -> void:
	var script_editor := EditorInterface.get_script_editor()
	var current_editor := script_editor.get_current_editor()
	if current_editor and current_editor.is_class("ScriptTextEditor"):
		var file: String = ProjectSettings.globalize_path(script_editor.get_current_script().resource_path)
		var project: String = ProjectSettings.globalize_path("res://")
		var exec_path: String = EditorInterface.get_editor_settings().get_setting("text_editor/external/exec_path")
		var exec_flags: String = EditorInterface.get_editor_settings().get_setting("text_editor/external/exec_flags")
		if exec_path and exec_flags:
			var col = current_editor.get_base_editor().get_caret_column(0)
			var line = current_editor.get_base_editor().get_caret_line(0)
			if exec_path.contains("rider"):
				var tabs := RegEx.create_from_string("\t*").search(current_editor.get_base_editor().get_line(line).substr(0, col))
				if tabs:
					col += tabs.get_string().length() * 3
			var arguments: Array[String] = []
			for flag in exec_flags.split(" "):
				arguments.append(flag.format({ "project": project, "col": col, "line": line + 1, "file": file }))
			OS.execute_with_pipe(exec_path, arguments, false)


func _shortcut_input(event: InputEvent) -> void:
	if Input.is_action_pressed(FORMAT_ACTION):
		_on_format_code()
		get_tree().root.set_input_as_handled()
	if Input.is_action_pressed(OPEN_EXTERNAL_ACTION):
		_open_external()
		get_tree().root.set_input_as_handled()
