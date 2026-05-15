extends Card


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["damage"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	if track_id == "damage":
		return PackedInt32Array([6, 9, 13])
	return PackedInt32Array()


func get_upgrade_pick_description_bbcode() -> String:
	var v := get_upgrade_value_at("damage")
	return "[center]造成%s点伤害。[/center]" % bbcode_upgrade_pick_digit("damage", v)


func _intrinsic_damage() -> int:
	return get_upgrade_value_at("damage")


func get_default_tooltip() -> String:
	return tooltip_text % _intrinsic_damage()


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
	var mx := is_upgrade_track_maxed("damage")
	return tooltip_text % bbcode_for_modified_number_with_upgrade_hint(modified_dmg, intrinsic, mx)


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
	var damage_effect := DamageEffect.new()
	damage_effect.amount = modifiers.get_modified_value(_intrinsic_damage(), Modifier.Type.DMG_DEALT)
	damage_effect.sound = sound
	damage_effect.execute(targets)
