extends EnemyAction

const ENTANGLED := preload("res://statuses/entangled.tres")

const ACTION_DURATION := 0.55


func get_planned_intents() -> Array[Intent]:
	if intent:
		return [intent]
	return []


func update_planned_intents() -> void:
	if intent:
		intent.display_number = Intent.NUMBER_HIDDEN
		if intent.base_text.is_empty():
			intent.current_text = "缠身"
		else:
			intent.current_text = intent.base_text


func perform_action() -> void:
	if not enemy or not target:
		return
	var target_array: Array[Node] = [target]
	_apply_entangled(target_array)
	SFXPlayer.play(sound)
	get_tree().create_timer(ACTION_DURATION, false).timeout.connect(
		func():
			if not is_instance_valid(enemy):
				return
			Events.enemy_action_completed.emit(enemy)
	)


func _apply_entangled(targets: Array[Node]) -> void:
	var entangled := ENTANGLED.duplicate()
	entangled.duration = 1
	var status_effect := StatusEffect.new()
	status_effect.status = entangled
	status_effect.execute(targets)
