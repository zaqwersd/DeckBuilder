extends EnemyAction

@export var heal_amount := 15


func perform_action() -> void:
	if not enemy or not is_instance_valid(enemy.stats):
		return
	enemy.stats.heal(heal_amount)
	var spook := _find_spook()
	if spook != null and is_instance_valid(spook.stats):
		spook.stats.heal(heal_amount)
	SFXPlayer.play(sound)
	await get_tree().create_timer(0.35).timeout
	if is_instance_valid(enemy):
		Events.enemy_action_completed.emit(enemy)


func update_intent_text() -> void:
	if intent:
		intent.display_number = Intent.NUMBER_HIDDEN


func _find_spook() -> Enemy:
	var handler := enemy.get_parent() as EnemyHandler
	if handler == null:
		return null
	return handler.find_live_spook()
