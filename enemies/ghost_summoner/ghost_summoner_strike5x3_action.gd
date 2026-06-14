extends EnemyAction

@export var hit_damage := 5
@export var hit_count := 3


func perform_action() -> void:
	if not enemy or not target:
		return
	var final_dmg := compute_damage_against_player(hit_damage)
	var tween := create_tween().set_trans(Tween.TRANS_QUINT)
	var start := enemy.global_position
	var end := EnemyAction.attack_lunge_position(start)
	var dmg_eff := make_final_player_damage_effect(final_dmg)
	var arr: Array[Node] = [target]
	tween.tween_property(enemy, "global_position", end, 0.36)
	for _i in hit_count:
		tween.tween_callback(dmg_eff.execute.bind(arr))
		tween.tween_interval(0.15)
	tween.tween_property(enemy, "global_position", start, 0.36)
	tween.finished.connect(
		func() -> void:
			if not is_instance_valid(enemy):
				return
			Events.enemy_action_completed.emit(enemy)
	)


func update_intent_text() -> void:
	if not intent:
		return
	var per_hit := hit_damage
	if enemy and target:
		per_hit = compute_damage_against_player(hit_damage)
	intent.set_attack_segments_display(per_hit, hit_count)
