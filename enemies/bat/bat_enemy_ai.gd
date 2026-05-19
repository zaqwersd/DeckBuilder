class_name BatEnemyAI
extends EnemyActionPicker

const ATTACK_ACTION_NAME := "BatAttackAction"

var _last_action_name: String = ""
var _consecutive_non_attack_turns: int = 0


func _ready() -> void:
	super._ready()
	if not Events.enemy_action_completed.is_connected(_on_enemy_action_completed):
		Events.enemy_action_completed.connect(_on_enemy_action_completed)


func _exit_tree() -> void:
	if Events.enemy_action_completed.is_connected(_on_enemy_action_completed):
		Events.enemy_action_completed.disconnect(_on_enemy_action_completed)


func get_action() -> EnemyAction:
	var pool := _build_action_pool()

	# 已连续两回合未攻击时，本回合必须攻击（不得连续三回合不攻击）
	if _consecutive_non_attack_turns >= 2:
		pool = pool.filter(func(action: EnemyAction) -> bool: return action.name == ATTACK_ACTION_NAME)
		if pool.is_empty():
			var attack := get_node_or_null(ATTACK_ACTION_NAME) as EnemyAction
			if attack:
				pool = [attack]

	return RNG.array_pick_random(pool) as EnemyAction


func _build_action_pool() -> Array[EnemyAction]:
	var pool: Array[EnemyAction] = []
	for child in get_children():
		if not child is EnemyAction:
			continue
		if not _last_action_name.is_empty() and child.name == _last_action_name:
			continue
		pool.append(child as EnemyAction)

	if pool.is_empty():
		for child in get_children():
			if child is EnemyAction:
				pool.append(child as EnemyAction)

	return pool


func _on_enemy_action_completed(completed_enemy: Enemy) -> void:
	if not is_instance_valid(enemy) or completed_enemy != enemy:
		return
	if not enemy.current_action:
		return

	_last_action_name = enemy.current_action.name
	if _last_action_name == ATTACK_ACTION_NAME:
		_consecutive_non_attack_turns = 0
	else:
		_consecutive_non_attack_turns += 1
