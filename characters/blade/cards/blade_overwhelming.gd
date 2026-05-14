extends Card

const OVERWHELMING_STATUS := preload("res://statuses/overwhelming_form.tres")


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["cost", "intrinsic_line"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	match track_id:
		"cost":
			return PackedInt32Array([2, 1])
		"intrinsic_line":
			return PackedInt32Array([0, 0])
		_:
			return PackedInt32Array()


func get_upgrade_pick_description_bbcode() -> String:
	var kw := _intrinsic_line_bb_pick()
	return "[center]%s[br]所有攻击牌伤害增加1倍。所有攻击牌耗能增加1。[/center]" % kw


func _intrinsic_line_bb_pick() -> String:
	if is_upgrade_track_maxed("intrinsic_line"):
		return "[color=#ffffff]固有。[/color]"
	return "[url=ugp:intrinsic_line][color=%s]固有。[/color][/url]" % BB_UPGRADE_INACTIVE_KEYWORD


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


func should_show_intrinsic_keyword_in_combat_description() -> bool:
	return intrinsic and is_upgrade_track_maxed("intrinsic_line")


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var status_effect := StatusEffect.new()
	var st := OVERWHELMING_STATUS.duplicate()
	st.stacks = 1
	status_effect.status = st
	status_effect.execute(targets)
