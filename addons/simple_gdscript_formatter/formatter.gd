const CodeOrder = preload("rules/code_order.gd")
const Spacing = preload("rules/spacing.gd")
const SyntaxStyle = preload("rules/syntax_style.gd")
const BlankLines = preload("rules/blank_lines.gd")


static func _apply_rules(code: String) -> String:
	code = Spacing.apply(code)

	code = SyntaxStyle.apply(code)
	code = Spacing.apply(code)

	code = CodeOrder.apply(code)
	code = Spacing.apply(code)

	code = BlankLines.apply(code)
	return code


static func _replace(text: String, what: String, forwhat: String) -> String:
	var index := text.find(what)
	if index != -1:
		text = text.substr(0, index) + forwhat + text.substr(index + what.length())
	return text


func format_code(code: String) -> String:
	var string_regex = RegEx.create_from_string(r"\&?([\"'])(?:(?=(\\?))\2[\s\S])*?\1")
	var string_matches = string_regex.search_all(code)
	var string_map = {}

	for i in range(string_matches.size()):
		var match = string_matches[i]
		var original = match.get_string()
		var placeholder = "__STRING__%d__" % i
		string_map[placeholder] = original
		code = _replace(code, original, placeholder)

	var disable_comment_regex = RegEx.create_from_string(r"#[^\s].*")
	var disable_comment_matches = disable_comment_regex.search_all(code)
	var disable_comment_map = {}

	for i in range(disable_comment_matches.size()):
		var match = disable_comment_matches[i]
		var original = match.get_string()
		var placeholder = "__COMMENT__CODE__%d__" % i
		disable_comment_map[placeholder] = original
		code = _replace(code, original, placeholder)

	var comment_regex = RegEx.create_from_string("#.*")
	var comment_matches = comment_regex.search_all(code)
	var comment_map = {}

	for i in range(comment_matches.size()):
		var match = comment_matches[i]
		var original = match.get_string()
		var placeholder = "__COMMENT__%d__" % i
		comment_map[placeholder] = original
		code = _replace(code, original, placeholder)

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
	for placeholder in disable_comment_map:
		code = code.replace(placeholder, disable_comment_map[placeholder])
	for placeholder in string_map:
		code = code.replace(placeholder, string_map[placeholder])
	for placeholder in breaker_map:
		code = code.replace(placeholder, breaker_map[placeholder])

	if code.length() > 0:
		code = code.strip_edges() + "\n"

	return code
