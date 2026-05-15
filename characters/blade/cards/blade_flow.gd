extends Card

const FLOW_STATE := preload("res://statuses/flow_state.tres")

const _DRAW_LINE_FULL := "每当有牌消耗，[br]抽1张牌。"
const _MANA_LINE_FULL := "每当有牌消耗，[br]获得1点能量。"
const _NOT_MASTERED_COMBAT := "你尚未掌握这个能力。"


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["cost", "draw_line", "mana_line"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	match track_id:
		"cost":
			return PackedInt32Array([3, 2])
		"draw_line":
			return PackedInt32Array([0, 0])
		"mana_line":
			return PackedInt32Array([0, 0])
		_:
			return PackedInt32Array()


func _has_any_flow_effect() -> bool:
	return is_upgrade_track_maxed("draw_line") or is_upgrade_track_maxed("mana_line")


func _draw_line_bbcode_listing() -> String:
	if is_upgrade_track_maxed("draw_line"):
		return _DRAW_LINE_FULL
	return CardKeywordTokens.bb_inactive_keyword(_DRAW_LINE_FULL, "draw_line")


func _mana_line_bbcode_listing() -> String:
	if is_upgrade_track_maxed("mana_line"):
		return _MANA_LINE_FULL
	return CardKeywordTokens.bb_inactive_keyword(_MANA_LINE_FULL, "mana_line")


func _draw_line_bbcode_combat() -> String:
	if not is_upgrade_track_maxed("draw_line"):
		return ""
	if is_visual_number_bbcode_combat():
		return "[color=%s]%s[/color]" % [COMBAT_BODY_TEXT, _DRAW_LINE_FULL]
	return _DRAW_LINE_FULL


func _mana_line_bbcode_combat() -> String:
	if not is_upgrade_track_maxed("mana_line"):
		return ""
	if is_visual_number_bbcode_combat():
		return "[color=%s]%s[/color]" % [COMBAT_BODY_TEXT, _MANA_LINE_FULL]
	return _MANA_LINE_FULL


func _effect_block_bbcode_for_listing() -> String:
	return "[center]%s[/center][center]%s[/center]" % [
		_draw_line_bbcode_listing(),
		_mana_line_bbcode_listing(),
	]


func _effect_block_bbcode_for_combat() -> String:
	if not _has_any_flow_effect():
		return "[center]%s[/center]" % _NOT_MASTERED_COMBAT
	var lines: PackedStringArray = PackedStringArray()
	var draw_bb := _draw_line_bbcode_combat()
	if not draw_bb.is_empty():
		lines.append("[center]%s[/center]" % draw_bb)
	var mana_bb := _mana_line_bbcode_combat()
	if not mana_bb.is_empty():
		lines.append("[center]%s[/center]" % mana_bb)
	return "".join(lines)


func get_upgrade_pick_description_bbcode() -> String:
	return _effect_block_bbcode_for_listing()


func get_default_tooltip() -> String:
	return _effect_block_bbcode_for_listing()


func get_updated_tooltip(
	_player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler, _combat_player: Node = null
) -> String:
	return get_default_tooltip()


func get_visual_description_bbcode() -> String:
	return get_updated_visual_description_bbcode(null, null, null)


func get_updated_visual_description_bbcode(
	_player_modifiers: ModifierHandler,
	_enemy_modifiers: ModifierHandler,
	_combat_player: Node = null
) -> String:
	var body := (
		_effect_block_bbcode_for_combat()
		if is_visual_number_bbcode_combat()
		else _effect_block_bbcode_for_listing()
	)
	return body


func _intrinsic_cost() -> int:
	return get_upgrade_value_at("cost")


func should_visualize_cost_as_upgradeable() -> bool:
	var ch := get_upgrade_chain("cost")
	if ch.is_empty():
		return false
	return not is_upgrade_track_maxed("cost")


func increment_upgrade_track(track_id: String) -> void:
	super.increment_upgrade_track(track_id)
	if track_id == "cost":
		cost = _intrinsic_cost()


func plays_card_sound_on_play() -> bool:
	return true


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var status_effect := StatusEffect.new()
	var st := FLOW_STATE.duplicate() as FlowStateStatus
	st.draw_on_exhaust = 1 if is_upgrade_track_maxed("draw_line") else 0
	st.mana_on_exhaust = 1 if is_upgrade_track_maxed("mana_line") else 0
	status_effect.status = st
	status_effect.execute(targets)
