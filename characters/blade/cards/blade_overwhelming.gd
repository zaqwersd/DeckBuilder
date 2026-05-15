extends Card

const OVERWHELMING_STATUS := preload("res://statuses/overwhelming_form.tres")


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["cost", "intrinsic_line", "damage_mult"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	match track_id:
		"cost":
			return PackedInt32Array([2, 1])
		"intrinsic_line":
			return PackedInt32Array([0, 0])
		"damage_mult":
			return PackedInt32Array([1, 2])
		_:
			return PackedInt32Array()


func get_upgrade_pick_description_bbcode() -> String:
	var kw := _intrinsic_line_bb_pick()
	var mult := get_upgrade_value_at("damage_mult")
	return "[center]%s[br]所有攻击牌伤害增加%s倍。所有攻击牌耗能增加1。[/center]" % [
		kw,
		bbcode_upgrade_pick_digit("damage_mult", mult)
	]


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


func sync_unlocked_intrinsic_flags_from_upgrade_tracks() -> void:
	## 仅当 intrinsic_line 升满轨后才为固有；与营火是否点过该轨一致，避免脏 `intrinsic` 与轨脱节。
	var ch := get_upgrade_chain("intrinsic_line")
	if ch.is_empty():
		return
	intrinsic = is_upgrade_track_maxed("intrinsic_line")


func get_visual_description_bbcode() -> String:
	return get_updated_visual_description_bbcode(null, null, null)


func get_updated_visual_description_bbcode(
	_player_modifiers: ModifierHandler,
	_enemy_modifiers: ModifierHandler,
	combat_player: Node = null
) -> String:
	var mult := get_upgrade_value_at("damage_mult")
	var mult_bb := bbcode_for_modified_number_with_upgrade_hint(
		mult, mult, is_upgrade_track_maxed("damage_mult")
	)
	# 注意：固有关键词由 CardVisuals._prepend_intrinsic_line_bbcode 自动添加，这里不需要重复添加
	return "[center]所有攻击牌伤害增加%s倍。所有攻击牌耗能增加1。[/center]" % mult_bb


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var status_effect := StatusEffect.new()
	var st := OVERWHELMING_STATUS.duplicate()
	## 传递升级后的伤害倍数到状态
	st.damage_multiplier = get_upgrade_value_at("damage_mult")
	st.stacks = 1
	status_effect.status = st
	status_effect.execute(targets)
