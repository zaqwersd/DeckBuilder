extends EnemyAction

const WEAK := preload("res://statuses/weak.tres")
const FRAIL := preload("res://statuses/frail.tres")

@export var weak_layers := 3
@export var frail_layers := 3
@export var weak_intent: Intent
@export var frail_intent: Intent


func get_planned_intents() -> Array[Intent]:
	var arr: Array[Intent] = []
	if weak_intent:
		arr.append(weak_intent)
	if frail_intent:
		arr.append(frail_intent)
	return arr


func update_planned_intents() -> void:
	if weak_intent:
		weak_intent.display_number = Intent.NUMBER_HIDDEN
		weak_intent.current_text = "虚弱" if weak_intent.base_text.is_empty() else weak_intent.base_text
	if frail_intent:
		frail_intent.display_number = Intent.NUMBER_HIDDEN
		frail_intent.current_text = "脆弱" if frail_intent.base_text.is_empty() else frail_intent.base_text


func perform_action() -> void:
	if not enemy or not target:
		return
	var target_array: Array[Node] = [target]
	_apply_status(WEAK, weak_layers, target_array)
	_apply_status(FRAIL, frail_layers, target_array)
	SFXPlayer.play(sound)
	get_tree().create_timer(0.65, false).timeout.connect(
		func():
			if not is_instance_valid(enemy):
				return
			Events.enemy_action_completed.emit(enemy)
	)


func _apply_status(template: Status, layers: int, targets: Array[Node]) -> void:
	var st := template.duplicate()
	st.duration = layers
	var status_effect := StatusEffect.new()
	status_effect.status = st
	status_effect.execute(targets)
