extends EnemyAction

@export var block := 10


func perform_action() -> void:
	if not enemy or not target:
		return
	var block_effect := BlockEffect.new()
	block_effect.amount = block
	block_effect.execute([enemy])
	get_tree().create_timer(0.6, false).timeout.connect(
		func() -> void:
			if not is_instance_valid(enemy):
				return
			var picker := enemy.enemy_action_picker
			if picker:
				picker.notify_picker_action_finished()
			Events.enemy_action_completed.emit(enemy)
	)


func update_intent_text() -> void:
	if intent:
		intent.display_number = block
		intent.current_text = ""
