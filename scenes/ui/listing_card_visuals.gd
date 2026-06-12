class_name ListingCardVisuals
extends "res://scenes/ui/card_visuals_base.gd"

## 战斗外卡牌（图鉴、牌库、商店、奖励、升级预览等）：
## - 已升级：绿色卡名 + upgraded 角标
## - 描述为默认字色，不显示黄/红/灰升级提示色


func _sync_cost_label_style() -> void:
	if not is_instance_valid(cost) or card == null:
		return
	cost.remove_theme_color_override("font_color")


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
	_apply_upgraded_name_style()
	type_label.remove_theme_color_override("font_color")
	_sync_upgrade_badge()
	_apply_description_default_color_for_style()
	_refresh_description_text()


func _apply_description_default_color_for_style() -> void:
	if not is_instance_valid(description_label):
		return
	description_label.remove_theme_color_override("default_color")


func _should_show_intrinsic() -> bool:
	if card == null:
		return false
	if card.intrinsic:
		return true
	for track_id in card.get_upgrade_track_ids():
		if track_id == "intrinsic_line":
			return true
	return false


func _is_intrinsic_maxed() -> bool:
	if card == null:
		return false
	if card.intrinsic:
		return true
	if card.is_upgrade_track_maxed("intrinsic_line"):
		return true
	return false


func _prepend_intrinsic_line_bbcode(raw: String) -> String:
	if not _should_show_intrinsic():
		return raw
	var kw_line := CardKeywordTokens.bb_mechanic_link("固有。", "intrinsic")
	return kw_line + "[br]" + raw


func _finalize_listing_description_bbcode(raw: String) -> String:
	return CardUpgradeUiColors.strip_listing_highlight_bbcode(raw)


func _refresh_description_text() -> void:
	if card == null:
		return
	if not _upgrade_pick_bbcode_override.is_empty():
		Card.push_visual_number_bbcode_style(Card.NumberBbcodeStyle.LISTING_PLAIN)
		var pick_raw := _finalize_listing_description_bbcode(_upgrade_pick_bbcode_override)
		_set_description_label_text(pick_raw)
		Card.pop_visual_number_bbcode_style()
		_apply_pick_through_nested_controls()
		_apply_description_default_color_for_style()
		return

	Card.push_visual_number_bbcode_style(Card.NumberBbcodeStyle.LISTING_PLAIN)
	var raw := _prepend_intrinsic_line_bbcode(
		card.get_updated_visual_description_bbcode(null, null, null)
	)
	Card.pop_visual_number_bbcode_style()
	raw = _finalize_listing_description_bbcode(raw)
	_set_description_label_text(raw)
	_apply_pick_through_nested_controls()
	_ensure_description_meta_signals()
	_apply_description_default_color_for_style()


func get_keyword_tooltip_ids() -> PackedStringArray:
	if card == null:
		return PackedStringArray()

	Card.push_visual_number_bbcode_style(Card.NumberBbcodeStyle.LISTING_PLAIN)
	var raw := _finalize_listing_description_bbcode(
		_prepend_intrinsic_line_bbcode(
			card.get_updated_visual_description_bbcode(null, null, null)
		)
	)
	Card.pop_visual_number_bbcode_style()

	var ids := CardKeywordBbcode.collect_tooltip_ids_from_raw_description(raw)
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
	return ids
