extends EnemyAction

const STRENGTH := preload("res://statuses/strength.tres")
const HAUNTED := preload("res://statuses/haunted.tres")

@export var str_intent: Intent
@export var debuff_intent: Intent
@export var strength_stacks := 2
@export var haunted_stacks := 1


func get_planned_intents() -> Array[Intent]:
	var arr: Array[Intent] = []
	if str_intent:
		arr.append(str_intent)
	if debuff_intent:
		arr.append(debuff_intent)
	return arr


func update_planned_intents() -> void:
	if str_intent:
		str_intent.display_number = Intent.NUMBER_HIDDEN
		str_intent.current_text = ""
	if debuff_intent:
		debuff_intent.display_number = Intent.NUMBER_HIDDEN
		debuff_intent.current_text = ""


func perform_action() -> void:
	if not enemy or not target:
		return
	var player := target as Player
	if not player:
		return
	var se_str := StatusEffect.new()
	var st := STRENGTH.duplicate()
	st.stacks = strength_stacks
	se_str.status = st
	se_str.execute([enemy])
	var se_h := StatusEffect.new()
	var h := HAUNTED.duplicate()
	h.stacks = haunted_stacks
	se_h.status = h
	se_h.execute([player])
	SFXPlayer.play(sound)
	var picker := enemy.enemy_action_picker
	if picker:
		picker.notify_picker_action_finished()
	Events.enemy_action_completed.emit(enemy)
