extends EnemyAction

@export var block := 12


func update_planned_intents() -> void:
	if intent:
		intent.display_number = block
		intent.current_text = ""


func perform_action() -> void:
	if enemy == null:
		return
	var effect := BlockEffect.new()
	effect.amount = block
	effect.execute([enemy])
	await get_tree().create_timer(0.25).timeout
	Events.enemy_action_completed.emit(enemy)