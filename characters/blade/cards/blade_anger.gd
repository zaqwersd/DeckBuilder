extends Card

const MUSCLE_STATUS = preload("res://statuses/strength.tres")


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["strength"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	if track_id == "strength":
		return PackedInt32Array([2, 3, 5])
	return PackedInt32Array()


func get_upgrade_pick_description_bbcode() -> String:
	var st := get_upgrade_value_at("strength")
	return "[center]获得 %s 点力量。[/center]" % bbcode_upgrade_pick_digit("strength", st)


func _intrinsic_strength() -> int:
	return get_upgrade_value_at("strength")


func get_default_tooltip() -> String:
	return tooltip_text % _intrinsic_strength()


func get_updated_tooltip(
	_player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler, _combat_player: Node = null
) -> String:
	var intrinsic := _intrinsic_strength()
	var mx := is_upgrade_track_maxed("strength")
	return tooltip_text % bbcode_for_modified_number_with_upgrade_hint(intrinsic, intrinsic, mx)


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var status_effect := StatusEffect.new()
	var muscle := MUSCLE_STATUS.duplicate()
	muscle.stacks = _intrinsic_strength()
	status_effect.status = muscle
	status_effect.execute(targets)
