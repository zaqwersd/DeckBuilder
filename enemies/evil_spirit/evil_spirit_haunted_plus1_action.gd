extends EnemyAction

const HAUNTED := preload("res://statuses/haunted.tres")

@export var debuff_intent: Intent


func get_planned_intents() -> Array[Intent]:
	if debuff_intent:
		return [debuff_intent]
	return super.get_planned_intents()


func update_planned_intents() -> void:
	if debuff_intent:
		debuff_intent.display_number = Intent.NUMBER_HIDDEN
		debuff_intent.current_text = ""


func perform_action() -> void:
	if not enemy or not target:
		return
	var player := target as Player
	if not player:
		return
	var se := StatusEffect.new()
	var h := HAUNTED.duplicate()
	h.stacks = 1
	se.status = h
	se.execute([player])
	SFXPlayer.play(sound)
	var picker := enemy.enemy_action_picker
	if picker:
		picker.notify_picker_action_finished()
	Events.enemy_action_completed.emit(enemy)
