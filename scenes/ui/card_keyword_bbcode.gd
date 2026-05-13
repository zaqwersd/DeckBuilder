class_name CardKeywordBbcode
extends RefCounted

## 为卡面/描述中的「虚无」「消耗」等注入 RichText meta（可点击样式）；词条说明由整张重合或列表悬停 UI 统一触发。
const META_ETHEREAL := "kw:ethereal"
const META_EXHAUST := "kw:exhaust"
const META_VULNERABLE := "kw:vulnerable"
const META_STRENGTH := "kw:strength"


static func inject_keywords(bbcode: String) -> String:
	if bbcode.is_empty():
		return bbcode
	var s := bbcode
	s = _wrap_each_token(s, "虚无", META_ETHEREAL)
	s = _wrap_each_token(s, "消耗", META_EXHAUST)
	s = _wrap_each_token(s, "易伤", META_VULNERABLE)
	s = _wrap_each_token(s, "力量", META_STRENGTH)
	return s


## 与卡面注入规则一致：用于「整张牌重合即显示」时收集要展示的词条块 id。
static func collect_tooltip_ids_from_raw_description(raw: String) -> PackedStringArray:
	if raw.is_empty():
		return PackedStringArray()
	var ids: PackedStringArray = PackedStringArray()
	var has_exhaust := false
	if raw.find("虚无") != -1:
		ids.append("ethereal")
		ids.append("exhaust")
		has_exhaust = true
	if raw.find("消耗") != -1 and not has_exhaust:
		ids.append("exhaust")
	if raw.find("易伤") != -1:
		ids.append("vulnerable")
	if raw.find("力量") != -1:
		ids.append("strength")
	return ids


static func _wrap_each_token(text: String, word: String, meta_key: String) -> String:
	var out := text
	var pos := 0
	var wrap := "[url=%s]%s[/url]" % [meta_key, word]
	while true:
		var f := out.find(word, pos)
		if f == -1:
			break
		if _inside_any_url(out, f):
			pos = f + word.length()
			continue
		out = out.substr(0, f) + wrap + out.substr(f + word.length())
		pos = f + wrap.length()
	return out


static func _inside_any_url(s: String, index: int) -> bool:
	var open := s.rfind("[url=", index)
	if open == -1:
		return false
	var close := s.rfind("[/url]", index)
	return open > close
