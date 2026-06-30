extends EnemyAction

const STRENGTH_STATUS := preload("res://statuses/strength.tres")

@export var strength_stacks := 3
@export var block := 20
@export var strength_intent: Intent
@export var block_intent: Intent


func get_planned_intents() -> Array[Intent]:
	var arr: Array[Intent] = []
	if strength_intent:
		arr.append(strength_intent)
	if block_intent:
		arr.append(block_intent)
	return arr


func update_planned_intents() -> void:
	if strength_intent:
		strength_intent.display_number = Intent.NUMBER_HIDDEN
		if strength_intent.base_text.is_empty():
			strength_intent.current_text = ""
		else:
			strength_intent.current_text = strength_intent.base_text % strength_stacks
	if block_intent:
		block_intent.display_number = block
		block_intent.current_text = ""


func perform_action() -> void:
	if not enemy:
		return
	var status_effect := StatusEffect.new()
	var strength := STRENGTH_STATUS.duplicate()
	strength.stacks = strength_stacks
	status_effect.status = strength
	status_effect.execute([enemy])
	var block_effect := BlockEffect.new()
	block_effect.amount = block
	block_effect.execute([enemy])
	SFXPlayer.play(sound)
	Events.enemy_action_completed.emit(enemy)
