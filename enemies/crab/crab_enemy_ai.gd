class_name CrabEnemyAI
extends EnemyActionPicker

var _last_action_name: String = ""
var assigned_action_name: StringName = &""
## 分配 4×n 意图时写入，供动作读取 n（当前战斗回合数）。
var planned_multihit_turn: int = 1


func get_action() -> EnemyAction:
	if assigned_action_name.is_empty():
		return null
	var path := NodePath(String(assigned_action_name))
	if not has_node(path):
		return null
	return get_node(path) as EnemyAction


func get_last_intent_id() -> int:
	return CrabIntentCoordinator.action_name_to_intent_id(_last_action_name)


func _ready() -> void:
	super._ready()
	if not Events.enemy_action_completed.is_connected(_on_enemy_action_completed):
		Events.enemy_action_completed.connect(_on_enemy_action_completed)


func _on_enemy_action_completed(completed_enemy: Enemy) -> void:
	if not is_instance_valid(enemy) or completed_enemy != enemy:
		return
	if not enemy.current_action:
		return
	_last_action_name = enemy.current_action.name



func _exit_tree() -> void:
	if Events.enemy_action_completed.is_connected(_on_enemy_action_completed):
		Events.enemy_action_completed.disconnect(_on_enemy_action_completed)
