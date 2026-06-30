extends EnemyAction

@export var damage := 9


func perform_action() -> void:
	if not enemy or not target:
		return

	var tween := create_tween().set_trans(Tween.TRANS_QUINT)
	var start := EnemyAction.attack_lunge_home(enemy)
	var end := EnemyAction.attack_lunge_position(start)
	var per_hit := compute_damage_against_player(damage)
	var damage_effect := make_final_player_damage_effect(per_hit)
	var target_array: Array[Node] = [target]

	tween.tween_property(enemy, "global_position", end, 0.4)
	tween.tween_callback(damage_effect.execute.bind(target_array))
	tween.tween_interval(0.25)
	tween.tween_property(enemy, "global_position", start, 0.4)

	tween.finished.connect(
		func():
			if not is_instance_valid(enemy):
				return
			Events.enemy_action_completed.emit(enemy)
	)


func update_intent_text() -> void:
	if not enemy or not target:
		return
	intent.set_attack_segments_display(compute_damage_against_player(damage), 1)
