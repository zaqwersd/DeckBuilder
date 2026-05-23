extends EnemyAction

const STRENGTH := preload("res://statuses/strength.tres")

@export var strength_stacks := 1


func get_planned_intents() -> Array[Intent]:
	if intent == null:
		return []
	return [intent]


func perform_action() -> void:
	if not is_instance_valid(enemy):
		return
	var status_effect := StatusEffect.new()
	var muscle := STRENGTH.duplicate()
	muscle.stacks = strength_stacks
	status_effect.status = muscle
	status_effect.execute([enemy])
	SFXPlayer.play(sound)
	call_deferred("_emit_action_completed")


func _emit_action_completed() -> void:
	if is_instance_valid(enemy):
		Events.enemy_action_completed.emit(enemy)


func update_intent_text() -> void:
	if intent == null:
		return
	intent.display_number = Intent.NUMBER_HIDDEN
	if intent.base_text.is_empty():
		intent.current_text = ""
	else:
		intent.current_text = intent.base_text % strength_stacks
