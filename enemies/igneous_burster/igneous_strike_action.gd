extends EnemyAction

@export var damage := 5


func perform_action() -> void:
	if not enemy or not target:
		return
	var player := target as Player
	if not player:
		return
	var modified := player.modifier_handler.get_modified_value(damage, Modifier.Type.DMG_TAKEN)
	var final_dmg := enemy.modifier_handler.get_modified_value(modified, Modifier.Type.DMG_DEALT)
	var tween := create_tween().set_trans(Tween.TRANS_QUINT)
	var start := enemy.global_position
	var end := EnemyAction.attack_lunge_position(start)
	var dmg_eff := DamageEffect.new()
	dmg_eff.amount = final_dmg
	dmg_eff.sound = sound
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
	var player := target as Player
	if not player or not enemy or not intent:
		return
	var modified := player.modifier_handler.get_modified_value(damage, Modifier.Type.DMG_TAKEN)
	var per_hit := enemy.modifier_handler.get_modified_value(modified, Modifier.Type.DMG_DEALT)
	intent.set_attack_segments_display(per_hit, 1)
