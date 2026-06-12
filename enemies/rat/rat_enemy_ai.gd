class_name RatEnemyAI
extends EnemyActionPicker

const WEAK_ACTION_NAME := &"RatStrike5Weak"
const ACTION_NAMES: Array[StringName] = [
	WEAK_ACTION_NAME,
	&"RatStrike2x6",
	&"RatStrike9",
]
const ACTION_WEIGHTS: Array[int] = [2, 1, 1]

var _last_action_name: String = ""
var _last_used_turn_by_action: Dictionary = {}
var _combat_turn_number: int = 0


func _ready() -> void:
	super._ready()
	if not Events.enemy_action_completed.is_connected(_on_enemy_action_completed):
		Events.enemy_action_completed.connect(_on_enemy_action_completed)


func _exit_tree() -> void:
	if Events.enemy_action_completed.is_connected(_on_enemy_action_completed):
		Events.enemy_action_completed.disconnect(_on_enemy_action_completed)


func get_action() -> EnemyAction:
	_combat_turn_number += 1

	if _combat_turn_number == 1:
		return get_node_or_null(String(WEAK_ACTION_NAME)) as EnemyAction

	var pool := _build_action_pool()
	return _pick_weighted_from_pool(pool)


func _get_all_actions() -> Array[EnemyAction]:
	var actions: Array[EnemyAction] = []
	for action_name in ACTION_NAMES:
		var action := get_node_or_null(String(action_name)) as EnemyAction
		if action:
			actions.append(action)
	return actions


func _build_action_pool() -> Array[EnemyAction]:
	var all_actions := _get_all_actions()
	var candidates: Array = all_actions.duplicate()
	candidates = EnemyIntentRotation.filter_no_consecutive_repeat(
		candidates,
		_last_action_name,
		func(action: EnemyAction) -> String: return action.name,
	)
	candidates = EnemyIntentRotation.filter_must_reappear(
		candidates,
		_combat_turn_number,
		func(action_name: String) -> int: return int(_last_used_turn_by_action.get(action_name, 0)),
		func(action: EnemyAction) -> String: return action.name,
	)
	var pool: Array[EnemyAction] = []
	for item in candidates:
		var action := item as EnemyAction
		if action:
			pool.append(action)
	return pool


func _pick_weighted_from_pool(pool: Array[EnemyAction]) -> EnemyAction:
	if pool.is_empty():
		return null
	var total := 0
	var weights: Array[int] = []
	for action in pool:
		var idx := ACTION_NAMES.find(StringName(action.name))
		var weight := ACTION_WEIGHTS[idx] if idx >= 0 else 1
		weights.append(weight)
		total += weight
	var roll := RNG.instance.randi_range(0, total - 1)
	var acc := 0
	for i in pool.size():
		acc += weights[i]
		if roll < acc:
			return pool[i]
	return pool[pool.size() - 1]


func _on_enemy_action_completed(completed_enemy: Enemy) -> void:
	if not is_instance_valid(enemy) or completed_enemy != enemy:
		return
	if not enemy.current_action:
		return
	_last_action_name = enemy.current_action.name
	_last_used_turn_by_action[_last_action_name] = _combat_turn_number
