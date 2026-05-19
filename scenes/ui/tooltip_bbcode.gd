class_name TooltipBbcode
extends RefCounted

const TITLE_COLOR := "#ffdd33"


static func escape_brackets(text: String) -> String:
	return text.replace("[", "[lb]").replace("]", "[rb]")


static func title_line(title: String) -> String:
	var safe := escape_brackets(title.strip_edges())
	if safe.is_empty():
		return ""
	return "[color=%s][b]%s[/b][/color]" % [TITLE_COLOR, safe]


static func titled(title: String, body: String) -> String:
	var body_stripped := body.strip_edges()
	var t := title_line(title)
	if t.is_empty():
		return body_stripped
	if body_stripped.is_empty():
		return t
	return "%s\n%s" % [t, body_stripped]
