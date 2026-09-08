extends RefCounted
## All token ranges are half-open [first_token, last_token).
## The original stream owns trivia; nodes only reference ranges in that stream.

enum Kind {
	SCRIPT, ANNOTATION, ANNOTATION_LIST, CLASS_NAME_DECL, EXTENDS_DECL,
	CLASS_DECL, VARIABLE_DECL, CONSTANT_DECL, SIGNAL_DECL, ENUM_DECL,
	FUNCTION_DECL, OPAQUE_EXPRESSION, OPAQUE_BLOCK, DELIMITED, COMMENT,
}

class CstNode:
	var kind: int
	var first_token: int
	var last_token: int
	var children: Array = []
	var attributes: Dictionary = {}

	func _init(node_kind: int, first: int, last: int = -1) -> void:
		kind = node_kind
		first_token = first
		last_token = first if last < 0 else last


var tokens: Array = []
var root: CstNode
var errors: Array[String] = []


func text(first: int, last: int) -> String:
	var parts := PackedStringArray()
	for i in range(first, last):
		parts.append(tokens[i].text)
	return "".join(parts)


func member_name(node: CstNode) -> String:
	var index: int = node.attributes.get("name_token", -1)
	return tokens[index].text if index >= 0 else ""


func has_annotation(node: CstNode, annotation_name: String) -> bool:
	for annotation in node.attributes.get("annotations", []):
		if tokens[annotation.first_token].text == "@" + annotation_name:
			return true
	return false


func is_static(node: CstNode) -> bool:
	return node.attributes.get("static", false)


func is_private(node: CstNode) -> bool:
	return member_name(node).begins_with("_")
