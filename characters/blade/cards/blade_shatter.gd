extends Card

const MUSCLE_STATUS = preload("res://statuses/strength.tres")


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["damage", "strength_loss"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	match track_id:
		"damage":
			return PackedInt32Array([27, 32])
		"strength_loss":
			return PackedInt32Array([2, 1])
		_:
			return PackedInt32Array()


func get_upgrade_pick_description_bbcode() -> String:
	var d := get_upgrade_value_at("damage")
	var sl := get_upgrade_value_at("strength_loss")
	return "[center]对所有敌人造成 %s 点伤害。[br]失去 %s 点力量。[/center]" % [
		bbcode_upgrade_pick_digit("damage", d),
		bbcode_upgrade_pick_negative_digit("strength_loss", sl),
	]


func _intrinsic_damage() -> int:
	return get_upgrade_value_at("damage")


func _intrinsic_strength_loss() -> int:
	return get_upgrade_value_at("strength_loss")


func get_default_tooltip() -> String:
	var d := _intrinsic_damage()
	var sl := _intrinsic_strength_loss()
	return (
		"[center]对所有敌人造成 %s 点伤害。[br]失去 %s 点力量。[/center]"
		% [str(d), _bbcode_strength_loss(sl)]
	)


func get_updated_tooltip(
	player_modifiers: ModifierHandler, enemy_modifiers: ModifierHandler, combat_player: Node = null
) -> String:
	var intrinsic := _intrinsic_damage()
	var modified_dmg := intrinsic
	if player_modifiers:
		modified_dmg = player_modifiers.get_modified_value(intrinsic, Modifier.Type.DMG_DEALT)
	if enemy_modifiers:
		modified_dmg = enemy_modifiers.get_modified_value(modified_dmg, Modifier.Type.DMG_TAKEN)
	modified_dmg = OverwhelmingStatus.apply_to_attack_card_preview_damage(combat_player, modified_dmg, type)
	var dmg_bb := bbcode_for_modified_number_with_upgrade_hint(
		modified_dmg, intrinsic, is_upgrade_track_maxed("damage")
	)
	var sl := _intrinsic_strength_loss()
	var sl_bb := _bbcode_strength_loss(sl)
	return "[center]对所有敌人造成 %s 点伤害。[br]失去 %s 点力量。[/center]" % [dmg_bb, sl_bb]


func _bbcode_strength_loss(amount: int) -> String:
	if Card.is_visual_number_bbcode_combat():
		return str(amount)
	if is_upgrade_track_maxed("strength_loss"):
		return str(amount)
	return "[color=%s]%d[/color]" % [BB_UPGRADE_NEGATIVE_REMOVABLE, amount]


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
	var damage_effect := DamageEffect.new()
	damage_effect.amount = modifiers.get_modified_value(_intrinsic_damage(), Modifier.Type.DMG_DEALT)
	damage_effect.sound = sound
	damage_effect.execute(targets)

	var player := _find_player(targets)
	if not player or not player.get("status_handler"):
		return
	var handler: StatusHandler = player.status_handler
	var dec := MUSCLE_STATUS.duplicate()
	dec.stacks = -_intrinsic_strength_loss()
	handler.add_status(dec)


func _find_player(targets: Array[Node]) -> Node:
	if not targets.is_empty() and is_instance_valid(targets[0]) and targets[0].is_inside_tree():
		return targets[0].get_tree().get_first_node_in_group("player")
	return null
