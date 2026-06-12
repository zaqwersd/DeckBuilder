extends Card

const OVERWHELMING_STATUS := preload("res://statuses/overwhelming_form.tres")


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["damage_mult"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	match track_id:
		"damage_mult":
			return PackedInt32Array([1, 2])
		_:
			return PackedInt32Array()


func get_upgrade_pick_description_bbcode() -> String:
	var mult := get_upgrade_value_at("damage_mult")
	return "[center]所有攻击牌伤害增加%s倍。所有攻击牌耗能增加1。[/center]" % (
		bbcode_upgrade_pick_digit("damage_mult", mult)
	)


func sync_unlocked_intrinsic_flags_from_upgrade_tracks() -> void:
	intrinsic = false


func _apply_upgraded_state() -> void:
	super._apply_upgraded_state()
	intrinsic = false


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
	return "[center]所有攻击牌伤害增加%s倍。所有攻击牌耗能增加1。[/center]" % mult_bb


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var status_effect := StatusEffect.new()
	var st := OVERWHELMING_STATUS.duplicate()
	## 传递升级后的伤害倍数到状态
	st.damage_multiplier = get_upgrade_value_at("damage_mult")
	st.stacks = 1
	status_effect.status = st
	status_effect.execute(targets)
