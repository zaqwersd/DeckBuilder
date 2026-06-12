class_name EnemyActionPicker
extends Node

@export var enemy: Enemy: set = _set_enemy
@export var target: Node2D: set = _set_target

@onready var total_weight := 0.0


func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		player = get_tree().get_first_node_in_group("battle_player") as Node2D
	if player:
		target = player
	setup_chances()


func get_action() -> EnemyAction:
	var action := get_first_conditional_action()
	if action:
		return action
		
	return get_chance_based_action()


func get_first_conditional_action() -> EnemyAction:
	for child in get_children():
		var action := child as EnemyAction
		if action == null or action.type != EnemyAction.Type.CONDITIONAL:
			continue
		if action.is_performable():
			return action
	return null


func get_chance_based_action() -> EnemyAction:
	var roll := RNG.instance.randf_range(0.0, total_weight)
	for child in get_children():
		var action := child as EnemyAction
		if action == null or action.type != EnemyAction.Type.CHANCE_BASED:
			continue
		if action.accumulated_weight > roll:
			return action
	return null


func setup_chances() -> void:
	for child in get_children():
		var action := child as EnemyAction
		if action == null or action.type != EnemyAction.Type.CHANCE_BASED:
			continue
		total_weight += action.chance_weight
		action.accumulated_weight = total_weight


## 自定义 AI（如 Boss）在单次行动真正结束、即将 `emit enemy_action_completed` 前调用；默认无操作。
func notify_picker_action_finished() -> void:
	pass


func _set_enemy(value: Enemy) -> void:
	enemy = value
	if target == null and is_instance_valid(enemy):
		var tree := enemy.get_tree()
		if tree:
			var player := tree.get_first_node_in_group("player") as Node2D
			if player == null:
				player = tree.get_first_node_in_group("battle_player") as Node2D
			if player:
				target = player
	for child in get_children():
		var action := child as EnemyAction
		if action:
			action.enemy = enemy


func _set_target(value: Node2D) -> void:
	target = value
	for child in get_children():
		var action := child as EnemyAction
		if action:
			action.target = target
