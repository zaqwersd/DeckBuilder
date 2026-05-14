# meta-name: Card Logic
# meta-description: What happens when a card is played.
extends Card

## 可升级牌：在脚本中覆盖 get_upgrade_track_ids、get_upgrade_chain、get_upgrade_pick_description_bbcode，
## 数值用 get_upgrade_value_at；满轨判断 is_upgrade_track_maxed；营火可点数字用 bbcode_upgrade_pick_digit 等（见 Card）。
## 卡面黄/红/灰与 ugp 链接：`CardKeywordTokens`；中文「虚无」「消耗」等由 `CardKeywordBbcode.inject_keywords` 自动加可点 `kw:` 与 tooltip。

@export var optional_sound: AudioStream


func get_default_tooltip() -> String:
	return tooltip_text


func get_updated_tooltip(_player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler, _combat_player: Node = null) -> String: # step 7.1
	return tooltip_text


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	print("My awesome card has been played!")
	print("Targets: %s" % targets)
