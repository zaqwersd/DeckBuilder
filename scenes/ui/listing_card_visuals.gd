class_name ListingCardVisuals
extends CardVisualsBase

## 战斗外卡牌的视觉显示规则（图鉴、牌库、商店、奖励等）：
## - 固有关键词：只要卡牌有 intrinsic 属性或可升级为固有，就显示（灰色表示未激活）
## - 数值颜色：黄/灰/红（BB_VALUE / BB_INACTIVE_KEYWORD / BB_NEGATIVE_REMOVABLE）
## - 显示所有升级相关信息（灰色表示未激活的升级）


func _sync_cost_label_style() -> void:
	if not is_instance_valid(cost) or card == null:
		return
	# 列表模式：费用可升级时显示黄色
	if card.cost >= 0 and card.should_visualize_cost_as_upgradeable():
		cost.add_theme_color_override("font_color", CardUpgradeUiColors.color_bb_value())
	else:
		cost.remove_theme_color_override("font_color")


func _sync_from_card() -> void:
	var dc := card.cost
	if _display_mana_cost_override >= 0:
		dc = _display_mana_cost_override
	if dc >= 0:
		cost.text = str(dc)
	else:
		cost.text = ""
	_sync_cost_label_style()
	icon.texture = card.icon
	name_label.text = card.get_display_name()
	type_label.text = TYPE_DISPLAY.get(card.type, "")
	# 列表模式：已升级卡牌显示绿色高亮
	if card.get_total_upgrade_count() > 0:
		name_label.add_theme_color_override("font_color", UPGRADED_CARD_ACCENT)
		name_label.add_theme_color_override("font_shadow_color", UPGRADED_FONT_OUTLINE)
		name_label.add_theme_constant_override("shadow_offset_x", -1)
		name_label.add_theme_constant_override("shadow_offset_y", 1)
		name_label.add_theme_constant_override("shadow_outline_size", 1)
	else:
		name_label.remove_theme_color_override("font_color")
		name_label.remove_theme_color_override("font_shadow_color")
		name_label.remove_theme_constant_override("shadow_offset_x")
		name_label.remove_theme_constant_override("shadow_offset_y")
		name_label.remove_theme_constant_override("shadow_outline_size")
	type_label.remove_theme_color_override("font_color")
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
	# 列表模式不覆盖默认颜色，让 RichTextLabel 使用主题颜色
	description_label.remove_theme_color_override("default_color")


func _should_show_intrinsic() -> bool:
	## 列表模式：显示固有关键词如果
	## 1. 卡牌已经是 intrinsic
	## 2. 或者卡牌有可升级获得固有属性的轨道（如巨剑的 intrinsic_line）
	if card == null:
		return false
	if card.intrinsic:
		return true
	# 检查是否有 intrinsic_line 升级轨道（可升级为固有）
	for track_id in card.get_upgrade_track_ids():
		if track_id == "intrinsic_line":
			return true
	return false


func _is_intrinsic_maxed() -> bool:
	## 检查固有关键词是否已完全激活
	if card == null:
		return false
	if card.intrinsic:
		return true
	# 检查 intrinsic_line 是否已满级
	if card.is_upgrade_track_maxed("intrinsic_line"):
		return true
	return false


func _prepend_intrinsic_line_bbcode(raw: String) -> String:
	## 列表模式：显示固有关键词（灰色表示未激活，白色表示已激活）
	if not _should_show_intrinsic():
		return raw
	
	var is_maxed := _is_intrinsic_maxed()
	var kw_line: String
	
	if is_maxed:
		# 已激活：白色
		kw_line = "[color=#ffffff][url=kw:intrinsic]固有。[/url][/color]"
	else:
		# 未激活：灰色
		kw_line = "[color=%s][url=kw:intrinsic]固有。[/url][/color]" % CardUpgradeUiColors.BB_INACTIVE_KEYWORD
	
	return kw_line + "[br]" + raw


func _refresh_description_text() -> void:
	if card == null:
		return
	if not _upgrade_pick_bbcode_override.is_empty():
		# 升级选择模式
		Card.push_visual_number_bbcode_style(Card.NumberBbcodeStyle.LISTING_UPGRADE)
		description_label.text = CardKeywordBbcode.wrap_ascii_digit_runs_bold(
			CardKeywordBbcode.inject_keywords(_upgrade_pick_bbcode_override)
		)
		Card.pop_visual_number_bbcode_style()
		_apply_pick_through_nested_controls()
		_apply_description_default_color_for_style()
		return
	
	Card.push_visual_number_bbcode_style(Card.NumberBbcodeStyle.LISTING_UPGRADE)
	# 列表模式：不使用战斗修饰器
	var raw := _prepend_intrinsic_line_bbcode(
		card.get_updated_visual_description_bbcode(null, null, null)
	)
	Card.pop_visual_number_bbcode_style()
	description_label.text = CardKeywordBbcode.wrap_ascii_digit_runs_bold(CardKeywordBbcode.inject_keywords(raw))
	_apply_pick_through_nested_controls()
	_ensure_description_meta_signals()
	_apply_description_default_color_for_style()


func get_keyword_tooltip_ids() -> PackedStringArray:
	if card == null:
		return PackedStringArray()
	
	Card.push_visual_number_bbcode_style(Card.NumberBbcodeStyle.LISTING_UPGRADE)
	var raw := _prepend_intrinsic_line_bbcode(
		card.get_updated_visual_description_bbcode(null, null, null)
	)
	Card.pop_visual_number_bbcode_style()
	
	var ids := CardKeywordBbcode.collect_tooltip_ids_from_raw_description(raw)
	# 列表模式：只要有固有关键词就添加到 tooltip
	if _should_show_intrinsic():
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
	
	# 收集颜色说明 IDs（基于描述中的颜色标记）
	ids = _append_color_tooltip_ids(ids, raw)
	return ids


## 根据描述中的颜色标记添加对应的颜色说明 tooltip IDs
## 颜色说明排在词条上方（先添加颜色说明，再添加词条）
func _append_color_tooltip_ids(ids: PackedStringArray, raw_bbcode: String) -> PackedStringArray:
	var color_ids: PackedStringArray = PackedStringArray()
	var has_yellow := raw_bbcode.find("#ffee58") != -1 or raw_bbcode.find("color=%s" % CardUpgradeUiColors.BB_VALUE) != -1
	var has_red := raw_bbcode.find("#f36c60") != -1 or raw_bbcode.find("color=%s" % CardUpgradeUiColors.BB_NEGATIVE_REMOVABLE) != -1
	var has_gray := raw_bbcode.find("#b0bec5") != -1 or raw_bbcode.find("color=%s" % CardUpgradeUiColors.BB_INACTIVE_KEYWORD) != -1
	
	# 先收集颜色说明 IDs（排在前面）
	if has_yellow:
		color_ids.append("color_yellow")
	if has_red:
		color_ids.append("color_red")
	if has_gray:
		color_ids.append("color_gray")
	
	# 合并：颜色说明在前，词条在后（去重）
	var result := color_ids.duplicate()
	for id in ids:
		if not result.has(id):
			result.append(id)
	
	return result
