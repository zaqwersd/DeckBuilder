extends Card

const MUSCLE_STATUS = preload("res://statuses/muscle.tres")
const MUSCLE_LOSS := 2

var base_damage := 27


func get_default_tooltip() -> String:
	return tooltip_text % base_damage


func get_updated_tooltip(player_modifiers: ModifierHandler, enemy_modifiers: ModifierHandler) -> String:
	var modified_dmg := base_damage
	if player_modifiers:
		modified_dmg = player_modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
	if enemy_modifiers:
		modified_dmg = enemy_modifiers.get_modified_value(modified_dmg, Modifier.Type.DMG_TAKEN)
	return tooltip_text % bbcode_for_modified_number(modified_dmg, base_damage)


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
	var damage_effect := DamageEffect.new()
	damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
	damage_effect.sound = sound
	damage_effect.execute(targets)

	var player := _find_player(targets)
	if not player or not player.get("status_handler"):
		return
	var handler: StatusHandler = player.status_handler
	var dec := MUSCLE_STATUS.duplicate()
	dec.stacks = -MUSCLE_LOSS
	handler.add_status(dec)


func _find_player(targets: Array[Node]) -> Node:
	if not targets.is_empty() and is_instance_valid(targets[0]) and targets[0].is_inside_tree():
		return targets[0].get_tree().get_first_node_in_group("player")
	return null
