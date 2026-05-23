extends EnemyAction


func get_planned_intents() -> Array[Intent]:
	if intent:
		return [intent]
	return []


func perform_action() -> void:
	if not is_instance_valid(enemy):
		return
	var armor := HeavyArmorStatus.get_on_enemy(enemy)
	if armor != null:
		armor.stun_next_enemy_turn = false
	get_tree().create_timer(0.35, false).timeout.connect(
		func():
			if not is_instance_valid(enemy):
				return
			Events.enemy_action_completed.emit(enemy)
	)
