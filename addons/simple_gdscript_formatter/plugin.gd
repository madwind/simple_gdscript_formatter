@tool
extends EditorPlugin

const FORMAT_ACTION = &"simple_gdscript_formatter/format"
const OPEN_EXTERNAL_ACTION = &"simple_gdscript_formatter/open_in_external_editor"
const FORMAT_MENU_ITEM = "Format GDScript / Shader"

var format_key: InputEventKey
var open_external_key: InputEventKey
var connected_code_edit_handlers: Dictionary = {}


func _enter_tree():
	add_tool_menu_item(FORMAT_MENU_ITEM, _on_format_code)
	get_tree().node_added.connect(_on_editor_node_added)
	call_deferred("_bind_code_edit_inputs")
	if InputMap.has_action(FORMAT_ACTION):
		InputMap.erase_action(FORMAT_ACTION)
	InputMap.add_action(FORMAT_ACTION)

	#Setting to enable/disable the open_in_external_editor feature
	if not ProjectSettings.has_setting(OPEN_EXTERNAL_ACTION):
		ProjectSettings.set_setting(OPEN_EXTERNAL_ACTION, true)
		ProjectSettings.set_initial_value(OPEN_EXTERNAL_ACTION, true)

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
	_unbind_code_edit_inputs()
	if get_tree().node_added.is_connected(_on_editor_node_added):
		get_tree().node_added.disconnect(_on_editor_node_added)
	remove_tool_menu_item(FORMAT_MENU_ITEM)
	InputMap.erase_action(FORMAT_ACTION)
	remove_tool_menu_item("Open In External Editor")
	InputMap.erase_action(OPEN_EXTERNAL_ACTION)


func _on_format_code():
	# GDScript and shader files use separate ScriptEditor docks in Godot. Pick
	# the dock containing keyboard focus so both can share this shortcut.
	var current_editor = _get_focused_code_editor()
	_format_editor(current_editor)


func _format_editor(current_editor) -> void:
	if not current_editor or (not current_editor.is_class("ScriptTextEditor") and not current_editor.is_class("ShaderTextEditor")):
		return
	var code_edit = _find_code_edit(current_editor)
	if not code_edit:
		return
	var code = code_edit.text
	var formatter = preload("formatter.gd").new()
	var formatted_code: String
	if current_editor.is_class("ShaderTextEditor"):
		formatted_code = formatter.format_shader(code_edit)
	else:
		formatted_code = formatter.format(code_edit)
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


func _bind_code_edit_inputs() -> void:
	var code_edits: Array = []
	_collect_code_edits(get_tree().root, code_edits)
	for code_edit in code_edits:
		if connected_code_edit_handlers.has(code_edit):
			continue
		var handler := Callable(self, "_on_code_edit_gui_input").bind(code_edit)
		code_edit.gui_input.connect(handler)
		connected_code_edit_handlers[code_edit] = handler


func _on_editor_node_added(node: Node) -> void:
	if node.is_class("ScriptEditor") or node.is_class("ShaderTextEditor") or node.is_class("CodeEdit"):
		call_deferred("_bind_code_edit_inputs")


func _unbind_code_edit_inputs() -> void:
	for code_edit in connected_code_edit_handlers:
		var handler = connected_code_edit_handlers[code_edit]
		if is_instance_valid(code_edit) and code_edit.gui_input.is_connected(handler):
			code_edit.gui_input.disconnect(handler)
	connected_code_edit_handlers.clear()


func _collect_code_edits(node, result: Array) -> void:
	if node.is_class("ScriptEditor"):
		var current_editor = node.get_current_editor()
		if current_editor:
			var code_edit = _find_code_edit(current_editor)
			if code_edit and not result.has(code_edit):
				result.append(code_edit)
	for child in node.get_children():
		_collect_code_edits(child, result)


func _find_code_edit(node):
	if node and node.is_class("CodeEdit"):
		return node
	if not node:
		return null
	for child in node.get_children():
		var result = _find_code_edit(child)
		if result:
			return result
	return null


func _on_code_edit_gui_input(event: InputEvent, code_edit: CodeEdit) -> void:
	if not _is_format_event(event):
		return
	var current_editor = _find_text_editor_for_code_edit(code_edit)
	if current_editor:
		_format_editor(current_editor)
		code_edit.get_viewport().set_input_as_handled()


func _find_text_editor_for_code_edit(code_edit: CodeEdit):
	var node = code_edit
	while node:
		if node.is_class("ScriptTextEditor") or node.is_class("ShaderTextEditor"):
			return node
		node = node.get_parent()
	return null


func _is_format_event(event: InputEvent) -> bool:
	if event.is_action_pressed(FORMAT_ACTION):
		return true
	if event is InputEventKey:
		return event.pressed and not event.echo and event.keycode == KEY_L and event.ctrl_pressed and event.alt_pressed
	return false


func _get_focused_code_editor():
	var focus_owner := EditorInterface.get_base_control().get_viewport().gui_get_focus_owner()
	var focused_node = focus_owner
	while focused_node:
		if focused_node.is_class("ShaderTextEditor"):
			return focused_node
		focused_node = focused_node.get_parent()
	# A floating Shader Editor can use another Window viewport, so walk the
	# editor tree and check every ShaderTextEditor whose CodeEdit has focus.
	var shader_editor = _find_focused_shader_editor(get_tree().root, focus_owner)
	if shader_editor:
		return shader_editor
	return EditorInterface.get_script_editor().get_current_editor()


func _find_focused_shader_editor(node, focus_owner):
	if node.is_class("ScriptEditor"):
		var current_editor = node.get_current_editor()
		if current_editor and current_editor.is_class("ShaderTextEditor"):
			var current_shader_code_edit = _find_code_edit(current_editor)
			if (focus_owner and node.is_ancestor_of(focus_owner)) or (current_shader_code_edit and current_shader_code_edit.has_focus()):
				return current_editor
	if node.is_class("ShaderTextEditor"):
		var shader_code_edit = _find_code_edit(node)
		if shader_code_edit and shader_code_edit.has_focus():
			return node
	for child in node.get_children():
		var result = _find_focused_shader_editor(child, focus_owner)
		if result:
			return result
	return null


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
	# Format the current GDScript or shader editor.
	if _is_format_event(event):
		_on_format_code()
		get_tree().root.set_input_as_handled()
	#Open in External Editor- uses ProjectSettings to enable or disable feature.
	if ProjectSettings.get_setting(OPEN_EXTERNAL_ACTION, true):
		if Input.is_action_pressed(OPEN_EXTERNAL_ACTION):
			if event is InputEventKey and event.get_keycode_with_modifiers() == Key.KEY_E | KeyModifierMask.KEY_MASK_CTRL:
				_open_external()
				get_tree().root.set_input_as_handled()
