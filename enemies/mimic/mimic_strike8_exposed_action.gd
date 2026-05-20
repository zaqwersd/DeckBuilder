extends EnemyAction

const EXPOSED := preload("res://statuses/exposed.tres")

@export var damage := 8
@export var debuff_intent: Intent


func get_planned_intents() -> Array[Intent]:
	var arr: Array[Intent] = []
	if intent:
		arr.append(intent)
	if debuff_intent:
		arr.append(debuff_intent)
	return arr


func update_planned_intents() -> void:
	update_intent_text()
	if debuff_intent:
		debuff_intent.display_number = Intent.NUMBER_HIDDEN
		debuff_intent.current_text = debuff_intent.base_text


func perform_action() -> void:
	if not enemy or not target:
		return
	
	var tween := create_tween().set_trans(Tween.TRANS_QUINT)
	var start := enemy.global_position
	var end := EnemyAction.attack_lunge_position(start)
	var damage_effect := DamageEffect.new()
	var target_array: Array[Node] = [target]
	var modified_dmg := enemy.modifier_handler.get_modified_value(damage, Modifier.Type.DMG_DEALT)
	damage_effect.amount = modified_dmg
	damage_effect.sound = sound
	
	tween.tween_property(enemy, "global_position", end, 0.4)
	tween.tween_callback(damage_effect.execute.bind(target_array))
	tween.tween_interval(0.25)
	tween.tween_property(enemy, "global_position", start, 0.4)
	tween.tween_callback(_apply_exposed.bind(target_array))
	tween.tween_interval(0.15)
	
	tween.finished.connect(
		func():
			if not is_instance_valid(enemy):
				return
			Events.enemy_action_completed.emit(enemy)
	)


func _apply_exposed(targets: Array[Node]) -> void:
	var exposed := EXPOSED.duplicate()
	var status_effect := StatusEffect.new()
	status_effect.status = exposed
	status_effect.execute(targets)


func update_intent_text() -> void:
	var player := target as Player
	if not player or not enemy:
		return
	
	var modified_dmg := player.modifier_handler.get_modified_value(damage, Modifier.Type.DMG_TAKEN)
	var per_hit := enemy.modifier_handler.get_modified_value(modified_dmg, Modifier.Type.DMG_DEALT)
	intent.set_attack_segments_display(per_hit, 1)
