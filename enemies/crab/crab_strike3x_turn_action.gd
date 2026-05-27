extends EnemyAction

@export var damage_per_hit := 4


func perform_action() -> void:
	if not enemy or not target:
		return
	var hit_count := _hit_count_for_turn()
	if hit_count <= 0:
		Events.enemy_action_completed.emit(enemy)
		return
	var per_hit := compute_damage_against_player(damage_per_hit)
	var dmg_eff := make_final_player_damage_effect(per_hit)
	var arr: Array[Node] = [target]
	var tween := create_tween().set_trans(Tween.TRANS_QUINT)
	var start := enemy.global_position
	var end := EnemyAction.attack_lunge_position(start)
	tween.tween_property(enemy, "global_position", end, 0.32)
	for _i in hit_count:
		tween.tween_callback(dmg_eff.execute.bind(arr))
		tween.tween_interval(0.14)
	tween.tween_property(enemy, "global_position", start, 0.32)
	tween.finished.connect(
		func():
			if not is_instance_valid(enemy):
				return
			Events.enemy_action_completed.emit(enemy)
	)


func update_intent_text() -> void:
	if not enemy or not target or not intent:
		return
	var n := _hit_count_for_turn()
	intent.set_attack_segments_display(compute_damage_against_player(damage_per_hit), n)


func _hit_count_for_turn() -> int:
	var picker := enemy.enemy_action_picker if enemy else null
	if picker is CrabEnemyAI:
		return maxi(1, (picker as CrabEnemyAI).planned_multihit_turn)
	return maxi(1, CrabIntentCoordinator.get_combat_turn_number())
