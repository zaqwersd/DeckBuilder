class_name CardKeywordBbcode
extends RefCounted

## 卡面 RichText meta：词条说明由 CardKeywordTooltip / Events 统一显示
const META_KW_PREFIX := "kw:"

## 词条说明正文（可含嵌套 `[url=kw:…]`，嵌套展示时用 plain 版避免递归）
const TOOLTIP_BODY_ETHEREAL_WITH_LINKS := (
	"[color=#ffdd33][b]虚无[/b][/color]\n"
	+ "如果回合结束时此牌仍在你的手牌中，则将其[url=kw:exhaust][color=#ffdd33]消耗[/color][/url]。"
)
const TOOLTIP_BODY_ETHEREAL_PLAIN := (
	"[color=#ffdd33][b]虚无[/b][/color]\n"
	+ "如果回合结束时此牌仍在你的手牌中，则将其消耗。"
)

const TOOLTIP_BODY_EXHAUST_WITH_LINKS := (
	"[color=#ffdd33][b]消耗[/b][/color]\n"
	+ "被消耗的牌会进入你的消耗牌堆。"
)

const TOOLTIP_BODY_EXHAUST_PLAIN := TOOLTIP_BODY_EXHAUST_WITH_LINKS

const TOOLTIP_BODY_VULNERABLE_WITH_LINKS := "[color=#ffdd33][b]易伤[/b][/color]\n受到的伤害增加50%。"
const TOOLTIP_BODY_VULNERABLE_PLAIN := TOOLTIP_BODY_VULNERABLE_WITH_LINKS

const TOOLTIP_BODY_STRENGTH_WITH_LINKS := "[color=#ffdd33][b]力量[/b][/color]\n增加造成的伤害。"
const TOOLTIP_BODY_STRENGTH_PLAIN := TOOLTIP_BODY_STRENGTH_WITH_LINKS

const TOOLTIP_BODY_INTRINSIC := (
	"[color=%s][b]固有。[/b][/color]\n每场战斗开始时会优先将固有牌加入你的手牌。"
	% CardUpgradeUiColors.BB_INACTIVE_KEYWORD
)

## 自动为中文词包 `[url=kw:id]`；顺序靠前者先包，避免子串冲突。
const _AUTO_WRAP: Array[Dictionary] = [
	{"word": "虚无", "id": "ethereal"},
	{"word": "消耗", "id": "exhaust"},
	{"word": "易伤", "id": "vulnerable"},
	{"word": "力量", "id": "strength"},
]


static func inject_keywords(bbcode: String) -> String:
	if bbcode.is_empty():
		return bbcode
	var s := bbcode
	for row: Dictionary in _AUTO_WRAP:
		s = _wrap_each_token(s, str(row["word"]), META_KW_PREFIX + str(row["id"]))
	return s


## 将 BBCode 中 ASCII 数字串包成 [b]…[/b]（跳过方括号标签内，避免破坏 [url=/color= 等）。
static func wrap_ascii_digit_runs_bold(bbcode: String) -> String:
	if bbcode.is_empty():
		return bbcode
	var out := ""
	var i := 0
	var n := bbcode.length()
	while i < n:
		var ch := bbcode.substr(i, 1)
		if ch == "[":
			var close := bbcode.find("]", i)
			if close == -1:
				out += bbcode.substr(i)
				break
			out += bbcode.substr(i, close - i + 1)
			i = close + 1
			continue
		var u := bbcode.unicode_at(i)
		if u >= 48 and u <= 57:
			var start := i
			while i < n:
				var u2 := bbcode.unicode_at(i)
				if u2 >= 48 and u2 <= 57:
					i += 1
				else:
					break
			out += "[b]"
			out += bbcode.substr(start, i - start)
			out += "[/b]"
			continue
		out += ch
		i += 1
	return out


## 从已含 `[url=kw:xxx]` 的 BBCode 中按出现顺序收集词条 id（用于悬停说明链）。
static func collect_kw_ids_in_order_from_bbcode(bbcode: String) -> PackedStringArray:
	if bbcode.is_empty():
		return PackedStringArray()
	var out: PackedStringArray = PackedStringArray()
	var key := "[url=" + META_KW_PREFIX
	var i := 0
	while true:
		var f := bbcode.find(key, i)
		if f == -1:
			break
		var rest := bbcode.substr(f + key.length())
		var close := rest.find("]")
		if close == -1:
			break
		var id := rest.substr(0, close)
		out.append(id)
		i = f + key.length() + close + 1
	return out


## 与卡面注入规则一致：用于「整张牌重合即显示」时收集要展示的词条块 id（优先解析 url，其次兼容纯中文旧卡面）。
static func collect_tooltip_ids_from_raw_description(raw: String) -> PackedStringArray:
	if raw.is_empty():
		return PackedStringArray()
	var injected := inject_keywords(raw)
	var from_urls := collect_kw_ids_in_order_from_bbcode(injected)
	if not from_urls.is_empty():
		return from_urls
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


## Tooltip 单段正文；`embed_cross_links=false` 用于嵌套悬停子面板，避免再嵌套 url。
static func get_keyword_tooltip_body_bbcode(id: String, embed_cross_links: bool = true) -> String:
	match String(id):
		"ethereal":
			return TOOLTIP_BODY_ETHEREAL_WITH_LINKS if embed_cross_links else TOOLTIP_BODY_ETHEREAL_PLAIN
		"exhaust":
			return TOOLTIP_BODY_EXHAUST_WITH_LINKS if embed_cross_links else TOOLTIP_BODY_EXHAUST_PLAIN
		"vulnerable":
			return TOOLTIP_BODY_VULNERABLE_WITH_LINKS if embed_cross_links else TOOLTIP_BODY_VULNERABLE_PLAIN
		"strength":
			return TOOLTIP_BODY_STRENGTH_WITH_LINKS if embed_cross_links else TOOLTIP_BODY_STRENGTH_PLAIN
		"intrinsic":
			return TOOLTIP_BODY_INTRINSIC
		_:
			return ""


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
