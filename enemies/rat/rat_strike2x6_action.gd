extends EnemyAction

@export var hit_damage := 2
@export var hit_count := 6


func perform_action() -> void:
	if not enemy or not target:
		return

	var final_dmg := compute_damage_against_player(hit_damage)
	var tween := create_tween().set_trans(Tween.TRANS_QUINT)
	var start := enemy.global_position
	var end := EnemyAction.attack_lunge_position(start)
	var damage_effect := make_final_player_damage_effect(final_dmg)
	var target_array: Array[Node] = [target]

	tween.tween_property(enemy, "global_position", end, 0.4)
	for _i in hit_count:
		tween.tween_callback(damage_effect.execute.bind(target_array))
		tween.tween_interval(0.18)
	tween.tween_property(enemy, "global_position", start, 0.4)

	tween.finished.connect(
		func():
			if not is_instance_valid(enemy):
				return
			Events.enemy_action_completed.emit(enemy)
	)


func update_intent_text() -> void:
	if not enemy or not target or not intent:
		return
	intent.set_attack_segments_display(compute_damage_against_player(hit_damage), hit_count)
