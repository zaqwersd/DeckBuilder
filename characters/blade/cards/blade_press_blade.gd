extends Card

const EXPOSED_STATUS = preload("res://statuses/exposed.tres")


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["cost", "damage", "exposed_duration"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	match track_id:
		"cost":
			return PackedInt32Array([2, 1])
		"damage":
			return PackedInt32Array([8, 12])
		"exposed_duration":
			return PackedInt32Array([2, 3])
		_:
			return PackedInt32Array()


func get_upgrade_pick_description_bbcode() -> String:
	var d2 := get_upgrade_value_at("damage")
	var ex := get_upgrade_value_at("exposed_duration")
	return "[center]造成%s点伤害。[br]给予%s层易伤。[/center]" % [
		bbcode_upgrade_pick_digit("damage", d2),
		bbcode_upgrade_pick_digit("exposed_duration", ex),
	]


func _intrinsic_cost() -> int:
	return get_upgrade_value_at("cost")


func _intrinsic_damage() -> int:
	return get_upgrade_value_at("damage")


func _intrinsic_exposed_duration() -> int:
	return get_upgrade_value_at("exposed_duration")


func should_visualize_cost_as_upgradeable() -> bool:
	var ch := get_upgrade_chain("cost")
	if ch.is_empty():
		return false
	return not is_upgrade_track_maxed("cost")


func increment_upgrade_track(track_id: String) -> void:
	super.increment_upgrade_track(track_id)
	cost = _intrinsic_cost()


func _body_bbcode(
	use_modifiers: bool,
	player_modifiers: ModifierHandler,
	enemy_modifiers: ModifierHandler,
	combat_player: Node = null,
) -> String:
	var intrinsic := _intrinsic_damage()
	var modified := intrinsic
	if use_modifiers:
		if player_modifiers:
			modified = player_modifiers.get_modified_value(intrinsic, Modifier.Type.DMG_DEALT)
		if enemy_modifiers:
			modified = enemy_modifiers.get_modified_value(modified, Modifier.Type.DMG_TAKEN)
		modified = OverwhelmingStatus.apply_to_attack_card_preview_damage(combat_player, modified, type)
	var dbb := bbcode_for_modified_number_with_upgrade_hint(
		modified, intrinsic, is_upgrade_track_maxed("damage")
	)

	var ed := _intrinsic_exposed_duration()
	var ebb := bbcode_for_modified_number_with_upgrade_hint(
		ed, ed, is_upgrade_track_maxed("exposed_duration")
	)

	return "[center]造成%s点伤害。[br]给予%s层易伤。[/center]" % [dbb, ebb]


func get_default_tooltip() -> String:
	return _body_bbcode(false, null, null)


func get_updated_tooltip(
	player_modifiers: ModifierHandler, enemy_modifiers: ModifierHandler, combat_player: Node = null
) -> String:
	return _body_bbcode(true, player_modifiers, enemy_modifiers, combat_player)


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
	var damage_effect := DamageEffect.new()
	damage_effect.amount = modifiers.get_modified_value(_intrinsic_damage(), Modifier.Type.DMG_DEALT)
	damage_effect.sound = sound
	damage_effect.execute(targets)

	var status_effect := StatusEffect.new()
	var exposed := EXPOSED_STATUS.duplicate()
	exposed.duration = _intrinsic_exposed_duration()
	status_effect.status = exposed
	status_effect.execute(targets)
