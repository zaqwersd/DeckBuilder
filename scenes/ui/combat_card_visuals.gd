class_name CombatCardVisuals
extends CardVisualsBase

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
	# 战斗中：已升级卡牌显示绿色高亮，未升级显示白色
	if card.get_total_upgrade_count() > 0:
		name_label.add_theme_color_override("font_color", UPGRADED_CARD_ACCENT)
		name_label.add_theme_color_override("font_shadow_color", UPGRADED_FONT_OUTLINE)
		name_label.add_theme_constant_override("shadow_offset_x", -1)
		name_label.add_theme_constant_override("shadow_offset_y", 1)
		name_label.add_theme_constant_override("shadow_outline_size", 1)
	else:
		name_label.add_theme_color_override("font_color", Color.WHITE)
		name_label.remove_theme_color_override("font_shadow_color")
		name_label.remove_theme_constant_override("shadow_offset_x")
		name_label.remove_theme_constant_override("shadow_offset_y")
		name_label.remove_theme_constant_override("shadow_outline_size")
	type_label.add_theme_color_override("font_color", Color.WHITE)
	_sync_upgrade_badge()
	_apply_description_default_color_for_style()
	_refresh_description_text()


func _sync_upgrade_badge() -> void:
	if not is_instance_valid(upgrade_level_panel) or not is_instance_valid(upgrade_level_label) or card == null:
		return
	var n := card.get_total_upgrade_count()
	upgrade_level_panel.visible = n > 0
	if n > 0:
		upgrade_level_label.text = "%d↑" % n
		upgrade_level_label.add_theme_color_override("font_color", UPGRADED_CARD_ACCENT)
		upgrade_level_label.add_theme_color_override("font_shadow_color", UPGRADED_FONT_OUTLINE)
		upgrade_level_label.add_theme_constant_override("shadow_offset_x", -1)
		upgrade_level_label.add_theme_constant_override("shadow_offset_y", 1)
		upgrade_level_label.add_theme_constant_override("shadow_outline_size", 1)
	else:
		upgrade_level_label.remove_theme_color_override("font_color")
		upgrade_level_label.remove_theme_color_override("font_shadow_color")
		upgrade_level_label.remove_theme_constant_override("shadow_offset_x")
		upgrade_level_label.remove_theme_constant_override("shadow_offset_y")
		upgrade_level_label.remove_theme_constant_override("shadow_outline_size")


func _apply_description_default_color_for_style() -> void:
	if not is_instance_valid(description_label):
		return
	description_label.add_theme_color_override("default_color", Color.WHITE)


func _prepend_intrinsic_line_bbcode(raw: String) -> String:
	## 战斗中：只有 intrinsic == true 且卡牌显示固有描述时才添加
	if card == null or not card.intrinsic:
		return raw
	if not card.should_show_intrinsic_keyword_in_combat_description():
		return raw
	var kw_line := "[color=#ffffff][url=kw:intrinsic]固有。[/url][/color]"
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
	# 检查敌人修饰器是否仍然有效
	var valid_enemy_modifiers := _enemy_modifiers if is_instance_valid(_enemy_modifiers) else null
	var raw := _prepend_intrinsic_line_bbcode(
		card.get_updated_visual_description_bbcode(
			_player_modifiers, valid_enemy_modifiers, _combat_player_for_desc
		)
	)
	Card.pop_visual_number_bbcode_style()
	_set_description_label_text(raw)
	_apply_pick_through_nested_controls()
	_ensure_description_meta_signals()
	_apply_description_default_color_for_style()


func get_keyword_tooltip_ids() -> PackedStringArray:
	if card == null:
		return PackedStringArray()
	
	Card.push_visual_number_bbcode_style(Card.NumberBbcodeStyle.COMBAT_PILES_AND_HAND)
	var valid_enemy_modifiers := _enemy_modifiers if is_instance_valid(_enemy_modifiers) else null
	var raw := _prepend_intrinsic_line_bbcode(
		card.get_updated_visual_description_bbcode(
			_player_modifiers, valid_enemy_modifiers, _combat_player_for_desc
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
