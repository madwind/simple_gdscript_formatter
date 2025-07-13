static func apply(code: String) -> String:
	var origin_code = code
	var categorized_blocks: Dictionary[String, Array] = {
		"tool": [], # @tool
		"icon": [], # @icon
		"static_unload": [], # @static_unload
		"class_name": [], # class_name
		"extends": [], # extends
		"doc_comment": [], # ## doc comment
		"signals": [],
		"enums": [],
		"constants": [],
		"private_constants": [],
		"static_vars": [],
		"private_static_vars": [],
		"export_vars": [],
		"private_export_vars": [],
		"vars": [],
		"private_vars": [],
		"onready_vars": [],
		"private_onready_vars": [],
		"_static_init": [], # func _static_init()
		"static_methods": [], # other static methods
		"virtual__init": [], # func _init()
		"virtual__enter_tree": [], # func _enter_tree()
		"virtual__ready": [], # func _ready()
		"virtual__process": [], # func _process()
		"virtual__physics_process": [], # func _physics_process()
		"virtual_others": [], # other virtual methods (starting with "_")
		"custom_overridden": [], # func _custom()
		"methods": [], # remaining methods
		"private_methods": [], # remaining methods
		"subclasses": [], # class Foo, or class Bar extends ...,
	}

	code = extract_and_categorize(r"@tool", "tool", categorized_blocks, code, true)
	code = extract_and_categorize(r"@icon", "icon", categorized_blocks, code, true)
	code = extract_and_categorize(r"@static_unload", "static_unload", categorized_blocks, code, true)
	code = extract_and_categorize(r"@abstract[\S\s]+?class_name .*", "class_name", categorized_blocks, code, true)
	code = extract_and_categorize(r"@export(?:(?!var)[\S\s])*?var _", "private_export_vars", categorized_blocks, code, true)
	code = extract_and_categorize(r"@export[\S\s]*?var", "export_vars", categorized_blocks, code, true)
	code = extract_and_categorize(r"@onready(?:(?!var)[\S\s])*?var _", "private_onready_vars", categorized_blocks, code, true)
	code = extract_and_categorize(r"@onready(?:(?!var)[\S\s])*?var", "onready_vars", categorized_blocks, code, true)
	code = extract_and_categorize(r"@abstract[\S\s]+?func ", "methods", categorized_blocks, code, true)
	code = extract_and_categorize(r"@abstract[\S\s]+?class ", "subclasses", categorized_blocks, code, true)
	code = extract_and_categorize(r"class_name .*", "class_name", categorized_blocks, code)
	code = extract_and_categorize(r"extends .*", "extends", categorized_blocks, code)
	code = extract_and_categorize(r"signal .*", "signals", categorized_blocks, code)
	code = extract_and_categorize(r"enum", "enums", categorized_blocks, code)
	code = extract_and_categorize(r"const _", "private_constants", categorized_blocks, code)
	code = extract_and_categorize(r"const", "constants", categorized_blocks, code)
	code = extract_and_categorize(r"static var _", "private_static_vars", categorized_blocks, code)
	code = extract_and_categorize(r"static var", "static_vars", categorized_blocks, code)
	code = extract_and_categorize(r"var _", "private_vars", categorized_blocks, code)
	code = extract_and_categorize(r"var", "vars", categorized_blocks, code)
	code = extract_and_categorize(r"func _static_init", "_static_init", categorized_blocks, code)
	code = extract_and_categorize(r"static func", "static_methods", categorized_blocks, code)
	code = extract_and_categorize(r"func _init", "virtual__init", categorized_blocks, code)
	code = extract_and_categorize(r"func _enter_tree", "virtual__enter_tree", categorized_blocks, code)
	code = extract_and_categorize(r"func _ready", "virtual__ready", categorized_blocks, code)
	code = extract_and_categorize(r"func _process", "virtual__process", categorized_blocks, code)
	code = extract_and_categorize(r"func _physics_process", "virtual__physics_process", categorized_blocks, code)
	code = extract_and_categorize(r"func _(input|unhandled)", "virtual_others", categorized_blocks, code)
	code = extract_and_categorize(r"func _", "private_methods", categorized_blocks, code)
	code = extract_and_categorize(r"func ", "methods", categorized_blocks, code)
	code = extract_and_categorize(r"class ", "subclasses", categorized_blocks, code)
	assert(code.strip_edges() == "", "Unprocessed code:" + code + "\n Origin code:" + origin_code)
	var result := ""
	var i = 0
	for key in categorized_blocks:
		if i > 5:
			result += "\n"
		else:
			result = RegEx.create_from_string(r"\n{2,}").sub(result, "\n", true)
		for block: String in categorized_blocks.get(key):
			if not block.begins_with("\n") and result.length() > 0:
				result += "\n"
			result += block
		i += 1
	return result


static func extract_and_categorize(pattern: String, category_key: String, categorized_blocks: Dictionary, code: String, is_annotation := false) -> String:
	var regex_obj: RegEx
	var pre_pattern = r"((^|\n)\s*__COMMENT__.*)*(\n@.*)?(^|\n+)"
	if is_annotation:
		pre_pattern = r"((^|\n)s*__COMMENT__.*)*(^|\n+)"
	regex_obj = RegEx.create_from_string(pre_pattern + pattern + r"[\S\s]*?(?=(\n\s*__COMMENT__.*)*?\n+(@|[^\W_])|$)")
	var found_blocks := regex_obj.search_all(code)
	for found in found_blocks:
		categorized_blocks.get(category_key).append(found.get_string())
	return regex_obj.sub(code, "", true)
