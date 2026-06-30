extends EnemyAction

const WEAK := preload("res://statuses/weak.tres")
const FRAIL := preload("res://statuses/frail.tres")

@export var weak_intent: Intent
@export var frail_intent: Intent
@export var duration := 1


func get_planned_intents() -> Array[Intent]:
	var out: Array[Intent] = []
	if weak_intent:
		out.append(weak_intent)
	if frail_intent:
		out.append(frail_intent)
	return out


func update_planned_intents() -> void:
	if weak_intent:
		weak_intent.display_number = Intent.NUMBER_HIDDEN
		weak_intent.current_text = "虚弱"
	if frail_intent:
		frail_intent.display_number = Intent.NUMBER_HIDDEN
		frail_intent.current_text = "脆弱"


func perform_action() -> void:
	if target == null:
		return
	_apply_status(WEAK)
	_apply_status(FRAIL)
	await get_tree().create_timer(0.25).timeout
	Events.enemy_action_completed.emit(enemy)


func _apply_status(template: Status) -> void:
	var st := template.duplicate(true) as Status
	st.duration = duration
	var effect := StatusEffect.new()
	effect.status = st
	effect.execute([target])