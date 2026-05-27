class_name LittleSkeltonAI
extends EnemyActionPicker

const OSTEOGENESIS := preload("res://statuses/osteogenesis.tres")

var _last_action_name: String = ""
var _osteogenesis_spawned: bool = false
var assigned_action_name: StringName = &""
var must_attack_next_turn: bool = false


func _ready() -> void:
	super._ready()
	if not Events.enemy_action_completed.is_connected(_on_enemy_action_completed):
		Events.enemy_action_completed.connect(_on_enemy_action_completed)


func _exit_tree() -> void:
	if Events.enemy_action_completed.is_connected(_on_enemy_action_completed):
		Events.enemy_action_completed.disconnect(_on_enemy_action_completed)


func _set_enemy(value: Enemy) -> void:
	super._set_enemy(value)
	if value and not _osteogenesis_spawned:
		_osteogenesis_spawned = true
		call_deferred("_spawn_osteogenesis")


func _spawn_osteogenesis() -> void:
	if not is_instance_valid(enemy) or not enemy.status_handler:
		return
	if enemy.status_handler.get_status_by_id("osteogenesis") != null:
		return
	enemy.status_handler.add_status(OSTEOGENESIS.duplicate())


func get_action() -> EnemyAction:
	if assigned_action_name.is_empty():
		return null
	var path := NodePath(String(assigned_action_name))
	if not has_node(path):
		return null
	return get_node(path) as EnemyAction


func get_last_intent_id() -> int:
	return LittleSkeltonIntentCoordinator.action_name_to_intent_id(_last_action_name)


func _on_enemy_action_completed(completed_enemy: Enemy) -> void:
	if not is_instance_valid(enemy) or completed_enemy != enemy:
		return
	if not enemy.current_action:
		return
	_last_action_name = enemy.current_action.name
	if StringName(_last_action_name) == LittleSkeltonIntentCoordinator.ACTION_BUFF2:
		must_attack_next_turn = true
