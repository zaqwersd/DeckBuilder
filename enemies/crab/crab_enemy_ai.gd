class_name CrabEnemyAI
extends EnemyActionPicker

const ACTION_NAMES: Array[StringName] = [
	&"CrabBlock10",
	&"CrabStrike5Block5",
	&"CrabStrike11",
	&"CrabBuff5",
]

var _last_action_name: String = ""


func _ready() -> void:
	super._ready()
	if not Events.enemy_action_completed.is_connected(_on_enemy_action_completed):
		Events.enemy_action_completed.connect(_on_enemy_action_completed)


func _exit_tree() -> void:
	if Events.enemy_action_completed.is_connected(_on_enemy_action_completed):
		Events.enemy_action_completed.disconnect(_on_enemy_action_completed)


func get_action() -> EnemyAction:
	var pool := _build_action_pool()
	if pool.is_empty():
		var all := _get_all_actions()
		return all[0] if not all.is_empty() else null
	return RNG.array_pick_random(pool) as EnemyAction


func _get_all_actions() -> Array[EnemyAction]:
	var actions: Array[EnemyAction] = []
	for action_name in ACTION_NAMES:
		var action := get_node_or_null(String(action_name)) as EnemyAction
		if action:
			actions.append(action)
	return actions


func _build_action_pool() -> Array[EnemyAction]:
	var candidates: Array = _get_all_actions().duplicate()
	candidates = EnemyIntentRotation.filter_no_consecutive_repeat(
		candidates,
		_last_action_name,
		func(action: EnemyAction) -> String: return action.name,
	)
	var pool: Array[EnemyAction] = []
	for item in candidates:
		var action := item as EnemyAction
		if action:
			pool.append(action)
	return pool


func _on_enemy_action_completed(completed_enemy: Enemy) -> void:
	if not is_instance_valid(enemy) or completed_enemy != enemy:
		return
	if not enemy.current_action:
		return
	_last_action_name = enemy.current_action.name
