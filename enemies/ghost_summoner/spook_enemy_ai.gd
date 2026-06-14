class_name SpookEnemyAI
extends EnemyActionPicker

const ACTION_INTENT1 := &"Intent1"
const ACTION_INTENT2 := &"Intent2"

var _planned_intent2 := false


func _ready() -> void:
	super._ready()
	if not Events.enemy_action_completed.is_connected(_on_enemy_action_completed):
		Events.enemy_action_completed.connect(_on_enemy_action_completed)


func _exit_tree() -> void:
	if Events.enemy_action_completed.is_connected(_on_enemy_action_completed):
		Events.enemy_action_completed.disconnect(_on_enemy_action_completed)


func prepare_for_turn(first_turn: bool) -> void:
	if first_turn:
		_planned_intent2 = RNG.instance.randf() < 0.5


func is_planned_intent2() -> bool:
	return _planned_intent2


func get_action() -> EnemyAction:
	var intent1 := get_node_or_null(String(ACTION_INTENT1)) as EnemyAction
	var intent2 := get_node_or_null(String(ACTION_INTENT2)) as EnemyAction
	if _planned_intent2:
		return intent2 if intent2 else intent1
	return intent1 if intent1 else intent2


func get_first_conditional_action() -> EnemyAction:
	return null


func _on_enemy_action_completed(completed_enemy: Enemy) -> void:
	if not is_instance_valid(enemy) or completed_enemy != enemy:
		return
	_planned_intent2 = not _planned_intent2
