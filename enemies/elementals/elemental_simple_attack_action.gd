extends EnemyAction

@export var damage := 8


func update_planned_intents() -> void:
	if intent:
		intent.set_attack_segments_display(compute_damage_against_player(damage), 1)


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
	tween.finished.connect(
		func():
			if not is_instance_valid(enemy):
				return
			Events.enemy_action_completed.emit(enemy)
	)
