class_name SpiderEnemyAI
extends EnemyActionPicker

const ACTION_ENTANGLED := &"SpiderEntangled1"
const ACTION_STRIKE6_EXPOSED := &"SpiderStrike6Exposed"
const ACTION_STRIKE10 := &"SpiderStrike10"
const ACTION_NAMES: Array[StringName] = [
	ACTION_ENTANGLED,
	ACTION_STRIKE6_EXPOSED,
	ACTION_STRIKE10,
]
const ACTION_WEIGHTS: Array[int] = [1, 2, 2]
const FIXED_OPENING: Array[StringName] = [
	ACTION_ENTANGLED,
	ACTION_STRIKE6_EXPOSED,
	ACTION_STRIKE10,
]

var _last_action_name: String = ""
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
	if _combat_turn_number <= FIXED_OPENING.size():
		return get_node_or_null(String(FIXED_OPENING[_combat_turn_number - 1])) as EnemyAction
	return _pick_weighted_from_pool(_build_action_pool())


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
	if _last_action_name == String(ACTION_STRIKE6_EXPOSED):
		candidates = candidates.filter(
			func(action: EnemyAction) -> bool: return action.name != String(ACTION_ENTANGLED)
		)
	var pool: Array[EnemyAction] = []
	for item in candidates:
		var action := item as EnemyAction
		if action:
			pool.append(action)
	if pool.is_empty():
		return _get_all_actions()
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
