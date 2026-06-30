extends EnemyAction

@export var damage := 7
@export var block := 7
@export var block_intent: Intent


func get_planned_intents() -> Array[Intent]:
	var out: Array[Intent] = []
	if intent:
		out.append(intent)
	if block_intent:
		out.append(block_intent)
	return out


func update_planned_intents() -> void:
	if intent:
		intent.set_attack_segments_display(compute_damage_against_player(damage), 1)
	if block_intent:
		block_intent.display_number = block
		block_intent.current_text = ""


func perform_action() -> void:
	if not enemy or not target:
		return
	var tween := create_tween().set_trans(Tween.TRANS_QUINT)
	var start := EnemyAction.attack_lunge_home(enemy)
	var end := EnemyAction.attack_lunge_position(start)
	var damage_effect := make_final_player_damage_effect(compute_damage_against_player(damage))
	var target_array: Array[Node] = [target]
	tween.tween_property(enemy, "global_position", end, 0.28)
	tween.tween_callback(damage_effect.execute.bind(target_array))
	tween.tween_interval(0.16)
	tween.tween_property(enemy, "global_position", start, 0.28)
	tween.tween_callback(_apply_block)
	tween.finished.connect(func(): Events.enemy_action_completed.emit(enemy))


func _apply_block() -> void:
	if enemy == null:
		return
	var effect := BlockEffect.new()
	effect.amount = block
	effect.execute([enemy])