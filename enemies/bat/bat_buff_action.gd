extends EnemyAction

const STRENGTH_STATUS = preload("res://statuses/strength.tres")

@export var stacks_per_action := 2


func perform_action() -> void:
	if not enemy or not target:
		return

	var status_effect := StatusEffect.new()
	var strength := STRENGTH_STATUS.duplicate()
	strength.stacks = stacks_per_action
	status_effect.status = strength
	status_effect.execute([enemy])

	SFXPlayer.play(sound)
	Events.enemy_action_completed.emit(enemy)


func update_intent_text() -> void:
	if intent:
		intent.display_number = Intent.NUMBER_HIDDEN
		if intent.base_text.is_empty():
			intent.current_text = ""
		else:
			intent.current_text = intent.base_text % stacks_per_action
