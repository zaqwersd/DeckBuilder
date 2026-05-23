extends EnemyAction

@export var hit_damage := 4
@export var hit_count := 3


func perform_action() -> void:
	if not enemy or not target:
		return
	var player := target as Player
	if not player:
		return
	var modified := player.modifier_handler.get_modified_value(hit_damage, Modifier.Type.DMG_TAKEN)
	var final_dmg := enemy.modifier_handler.get_modified_value(modified, Modifier.Type.DMG_DEALT)
	var tween := create_tween().set_trans(Tween.TRANS_QUINT)
	var start := enemy.global_position
	var end := EnemyAction.attack_lunge_position(start)
	var dmg_eff := DamageEffect.new()
	dmg_eff.amount = final_dmg
	dmg_eff.sound = sound
	var arr: Array[Node] = [target]
	tween.tween_property(enemy, "global_position", end, 0.36)
	for _i in hit_count:
		tween.tween_callback(dmg_eff.execute.bind(arr))
		tween.tween_interval(0.18)
	tween.tween_property(enemy, "global_position", start, 0.36)
	tween.finished.connect(
		func():
			if not is_instance_valid(enemy):
				return
			var p := enemy.enemy_action_picker
			if p:
				p.notify_picker_action_finished()
			Events.enemy_action_completed.emit(enemy)
	)


func update_intent_text() -> void:
	var player := target as Player
	if not player or not enemy or not intent:
		return
	var modified := player.modifier_handler.get_modified_value(hit_damage, Modifier.Type.DMG_TAKEN)
	var final_dmg := enemy.modifier_handler.get_modified_value(modified, Modifier.Type.DMG_DEALT)
	intent.set_attack_segments_display(final_dmg, hit_count)
