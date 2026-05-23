extends EnemyAction

const STRENGTH := preload("res://statuses/strength.tres")
@export var stacks := 2


func perform_action() -> void:
	if not enemy or not target:
		return
	var se := StatusEffect.new()
	var st := STRENGTH.duplicate()
	st.stacks = stacks
	se.status = st
	se.execute([enemy])
	SFXPlayer.play(sound)
	var picker := enemy.enemy_action_picker
	if picker:
		picker.notify_picker_action_finished()
	Events.enemy_action_completed.emit(enemy)


func update_planned_intents() -> void:
	update_intent_text()


func update_intent_text() -> void:
	if intent:
		intent.display_number = Intent.NUMBER_HIDDEN
		intent.current_text = ""
