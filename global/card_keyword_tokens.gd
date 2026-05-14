class_name CardKeywordTokens
extends RefCounted

## 卡面/升级说明里预制「黄 / 红 / 灰」词条色（与 CardUpgradeUiColors 图例一致）。
## 可选 `ugp:轨id` 链接，供营火等 RichText meta 点击（与 CardUpgradeFlow 一致）。


static func bb_value(text: String, ugp_track: String = "") -> String:
	var esc := str(text)
	if ugp_track.is_empty():
		return "[color=%s]%s[/color]" % [CardUpgradeUiColors.BB_VALUE, esc]
	return "[url=ugp:%s][color=%s]%s[/color][/url]" % [ugp_track, CardUpgradeUiColors.BB_VALUE, esc]


static func bb_negative_removable(text: String, ugp_track: String = "") -> String:
	var esc := str(text)
	if ugp_track.is_empty():
		return "[color=%s]%s[/color]" % [CardUpgradeUiColors.BB_NEGATIVE_REMOVABLE, esc]
	return "[url=ugp:%s][color=%s]%s[/color][/url]" % [
		ugp_track,
		CardUpgradeUiColors.BB_NEGATIVE_REMOVABLE,
		esc,
	]


static func bb_inactive_keyword(text: String, ugp_track: String = "") -> String:
	var esc := str(text)
	if ugp_track.is_empty():
		return CardUpgradeUiColors.bbcode_inactive_keyword(esc)
	return "[url=ugp:%s][color=%s]%s[/color][/url]" % [
		ugp_track,
		CardUpgradeUiColors.BB_INACTIVE_KEYWORD,
		esc,
	]


## 与 `CardKeywordBbcode` 的 `kw:` meta 一致，用于在脚本里手写可点词条（不自动包色，便于自定义）。
static func bb_mechanic_link(display: String, kw_id: String) -> String:
	return "[url=kw:%s]%s[/url]" % [kw_id, str(display)]
