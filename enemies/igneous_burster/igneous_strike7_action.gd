extends EnemyAction

@export var damage := 7


func perform_action() -> void:
	if not enemy or not target:
		return
	var player := target as Player
	if not player:
		return
	var final_dmg := compute_damage_against_player(damage)
	var tween := create_tween().set_trans(Tween.TRANS_QUINT)
	var start := enemy.global_position
	var end := EnemyAction.attack_lunge_position(start)
	var dmg_eff := make_final_player_damage_effect(final_dmg)
	var arr: Array[Node] = [target]
	tween.tween_property(enemy, "global_position", end, 0.38)
	tween.tween_callback(dmg_eff.execute.bind(arr))
	tween.tween_interval(0.22)
	tween.tween_property(enemy, "global_position", start, 0.36)
	tween.finished.connect(
		func():
			if not is_instance_valid(enemy):
				return
			var p := enemy.enemy_action_picker
			if p and p.has_method("notify_igneous_strike_done"):
				p.notify_igneous_strike_done()
			Events.enemy_action_completed.emit(enemy)
	)


func update_intent_text() -> void:
	if not enemy or not target or not intent:
		return
	intent.set_attack_segments_display(compute_damage_against_player(damage), 1)
