extends RefCounted
## This module knows only layout, never GDScript syntax.

const Doc = preload("doc.gd")
const K = Doc.Kind


func print_doc(document, indent_text := "\t", width := 100, tab_size := 4) -> String:
	var stack: Array = [[0, false, document]]
	var result := ""
	var column := 0
	var pending_indent := true
	while not stack.is_empty():
		var command: Array = stack.pop_back()
		var level: int = command[0]
		var flat: bool = command[1]
		var doc = command[2]
		match doc.kind:
			K.TEXT:
				if doc.value.is_empty():
					continue
				if pending_indent:
					result += indent_text.repeat(level)
					column = _width(indent_text.repeat(level), tab_size)
					pending_indent = false
				result += doc.value
				var newline: int = doc.value.rfind("\n")
				column = _width(doc.value.substr(newline + 1), tab_size) if newline >= 0 else column + _width(doc.value, tab_size)
			K.LINE, K.SOFT_LINE:
				if doc.kind == K.SOFT_LINE and flat:
					result += doc.value
					column += _width(doc.value, tab_size)
				else:
					result += "\n"
					column = 0
					pending_indent = true
			K.CONCAT:
				for i in range(doc.children.size() - 1, -1, -1):
					stack.append([level, flat, doc.children[i]])
			K.INDENT:
				stack.append([level + doc.amount, flat, doc.children[0]])
			K.GROUP:
				var candidate: Array = stack.duplicate()
				candidate.append([level, true, doc.children[0]])
				var occupied := _width(indent_text.repeat(level), tab_size) if pending_indent else column
				var fits: bool = not doc.force_break and (flat or _fits(width - occupied, candidate, tab_size))
				stack.append([level, fits, doc.children[0]])
	return result


func _fits(remaining: int, stack: Array, tab_size: int) -> bool:
	while remaining >= 0 and not stack.is_empty():
		var command: Array = stack.pop_back()
		var flat: bool = command[1]
		var doc = command[2]
		match doc.kind:
			K.TEXT:
				if doc.value.contains("\n") or doc.value.contains("\r"):
					return false
				remaining -= _width(doc.value, tab_size)
			K.LINE:
				return not flat
			K.SOFT_LINE:
				if not flat:
					return true
				remaining -= _width(doc.value, tab_size)
			K.GROUP:
				if doc.force_break:
					return false
				stack.append([command[0], flat, doc.children[0]])
			K.INDENT:
				stack.append([command[0] + doc.amount, flat, doc.children[0]])
			K.CONCAT:
				for i in range(doc.children.size() - 1, -1, -1):
					stack.append([command[0], flat, doc.children[i]])
	return remaining >= 0


func _width(value: String, tab_size: int) -> int:
	return value.length() + value.count("\t") * (tab_size - 1)
