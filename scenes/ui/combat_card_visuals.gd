class_name CombatCardVisuals
extends "res://scenes/ui/card_visuals_base.gd"

## 战斗中卡牌的视觉显示规则：
## - 固有关键词：只有 intrinsic == true 且 should_show_intrinsic_keyword_in_combat_description() 才显示
## - 数值颜色：白底 + 红绿变化（COMBAT_MODIFIED_RED/GREEN）
## - 不显示灰色升级词条；不挂黄/红/灰「升级说明」tooltip（与局外 LISTING 语义不同）


func _sync_cost_label_style() -> void:
	if not is_instance_valid(cost) or card == null:
		return
	if card.is_x_cost():
		if not _combat_effective_mana_affordable:
			cost.add_theme_color_override(
				"font_color", CardUpgradeUiColors.color_bb_negative_removable()
			)
		else:
			cost.add_theme_color_override("font_color", Color.WHITE)
		return
	if card.cost >= 0:
		var display_cost := card.cost
		if _display_mana_cost_override >= 0:
			display_cost = _display_mana_cost_override
		if not _combat_effective_mana_affordable:
			cost.add_theme_color_override(
				"font_color", CardUpgradeUiColors.color_bb_negative_removable()
			)
		elif display_cost > card.cost:
			cost.add_theme_color_override("font_color", CardUpgradeUiColors.color_bb_value())
		elif display_cost < card.cost:
			cost.add_theme_color_override("font_color", UPGRADED_CARD_ACCENT)
		else:
			cost.add_theme_color_override("font_color", Color.WHITE)


func _sync_from_card() -> void:
	var dc := card.cost
	if _display_mana_cost_override >= 0:
		dc = _display_mana_cost_override
	if card.is_x_cost():
		cost.text = "X"
	elif dc >= 0:
		cost.text = str(dc)
	else:
		cost.text = ""
	_sync_cost_label_style()
	icon.texture = card.icon
	name_label.text = card.get_display_name()
	type_label.text = TYPE_DISPLAY.get(card.type, "")
	if card.is_upgraded:
		_apply_upgraded_name_style()
	else:
		name_label.add_theme_color_override("font_color", Color.WHITE)
		_clear_upgraded_name_style()
	type_label.add_theme_color_override("font_color", Color.WHITE)
	_sync_upgrade_badge()
	_apply_description_default_color_for_style()
	_refresh_description_text()


func _apply_description_default_color_for_style() -> void:
	if not is_instance_valid(description_label):
		return
	description_label.add_theme_color_override("default_color", Color.WHITE)


func _append_combat_effect_summary_line(raw: String, summary_line: String) -> String:
	var close := raw.rfind("[/center]")
	if close != -1:
		return raw.substr(0, close) + "[br]" + summary_line + raw.substr(close)
	if raw.contains("[center]"):
		return raw + "[br]" + summary_line
	return "[center]%s[/center][br][center]%s[/center]" % [raw, summary_line]


func _prepend_intrinsic_line_bbcode(raw: String) -> String:
	## 战斗中：只有 intrinsic == true 且卡牌显示固有描述时才添加
	if card == null or not card.intrinsic:
		return raw
	if not card.should_show_intrinsic_keyword_in_combat_description():
		return raw
	var kw_line := CardKeywordTokens.bb_mechanic_link("固有。", "intrinsic")
	return kw_line + "[br]" + raw


func _refresh_description_text() -> void:
	if card == null:
		return
	if not _upgrade_pick_bbcode_override.is_empty():
		# 战斗中的升级预览（理论上不应发生，但做安全处理）
		Card.push_visual_number_bbcode_style(Card.NumberBbcodeStyle.LISTING_UPGRADE)
		_set_description_label_text(_upgrade_pick_bbcode_override)
		Card.pop_visual_number_bbcode_style()
		_apply_pick_through_nested_controls()
		_apply_description_default_color_for_style()
		return
	
	Card.push_visual_number_bbcode_style(Card.NumberBbcodeStyle.COMBAT_PILES_AND_HAND)
	var valid_player_modifiers := _player_modifiers if is_instance_valid(_player_modifiers) else null
	var valid_enemy_modifiers := _enemy_modifiers if is_instance_valid(_enemy_modifiers) else null
	var valid_combat_player := _combat_player_for_desc if is_instance_valid(_combat_player_for_desc) else null
	var raw := _prepend_intrinsic_line_bbcode(
		card.get_updated_visual_description_bbcode(
			valid_player_modifiers, valid_enemy_modifiers, valid_combat_player
		)
	)
	var summary := card.get_combat_effect_summary_bbcode(
		valid_player_modifiers, valid_enemy_modifiers, valid_combat_player
	)
	if not summary.is_empty():
		raw = _append_combat_effect_summary_line(raw, summary)
	Card.pop_visual_number_bbcode_style()
	_set_description_label_text(raw)
	_apply_pick_through_nested_controls()
	_ensure_description_meta_signals()
	_apply_description_default_color_for_style()


func get_keyword_tooltip_ids() -> PackedStringArray:
	if card == null:
		return PackedStringArray()
	
	Card.push_visual_number_bbcode_style(Card.NumberBbcodeStyle.COMBAT_PILES_AND_HAND)
	var valid_player_modifiers := _player_modifiers if is_instance_valid(_player_modifiers) else null
	var valid_enemy_modifiers := _enemy_modifiers if is_instance_valid(_enemy_modifiers) else null
	var valid_combat_player := _combat_player_for_desc if is_instance_valid(_combat_player_for_desc) else null
	var raw := _prepend_intrinsic_line_bbcode(
		card.get_updated_visual_description_bbcode(
			valid_player_modifiers, valid_enemy_modifiers, valid_combat_player
		)
	)
	Card.pop_visual_number_bbcode_style()
	
	var ids := CardKeywordBbcode.collect_tooltip_ids_from_raw_description(raw)
	# 战斗中：只有 intrinsic == true 且显示固有描述时才添加 intrinsic 到 tooltip
	if card.intrinsic and card.should_show_intrinsic_keyword_in_combat_description():
		var has_intrinsic_id := false
		for i in range(ids.size()):
			if ids[i] == "intrinsic":
				has_intrinsic_id = true
				break
		if not has_intrinsic_id:
			var with_kw := PackedStringArray()
			with_kw.append("intrinsic")
			for i in range(ids.size()):
				with_kw.append(ids[i])
			ids = with_kw
	
	return CardKeywordBbcode.without_color_tooltip_ids(ids)
