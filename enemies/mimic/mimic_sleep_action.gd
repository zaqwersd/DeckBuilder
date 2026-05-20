extends EnemyAction


func perform_action() -> void:
	if not is_instance_valid(enemy):
		return
	get_tree().create_timer(0.35, false).timeout.connect(
		func():
			if not is_instance_valid(enemy):
				return
			Events.enemy_action_completed.emit(enemy)
	)
