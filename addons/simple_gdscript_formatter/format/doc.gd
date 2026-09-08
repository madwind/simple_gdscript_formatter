extends RefCounted
## Small, language-independent layout vocabulary.

enum Kind { TEXT, LINE, SOFT_LINE, CONCAT, INDENT, GROUP }

class Layout:
	var kind: int
	var value := ""
	var children: Array = []
	var amount := 1
	var force_break := false

	func _init(layout_kind: int) -> void:
		kind = layout_kind


static func text(value: String):
	var result = Layout.new(Kind.TEXT)
	result.value = value
	return result


static func line():
	return Layout.new(Kind.LINE)


static func soft_line(flat_text := " "):
	var result = Layout.new(Kind.SOFT_LINE)
	result.value = flat_text
	return result


static func concat(children: Array):
	var result = Layout.new(Kind.CONCAT)
	result.children = children
	return result


static func indent(child, amount := 1):
	var result = Layout.new(Kind.INDENT)
	result.children = [child]
	result.amount = amount
	return result


static func group(child, force_break := false):
	var result = Layout.new(Kind.GROUP)
	result.children = [child]
	result.force_break = force_break
	return result
