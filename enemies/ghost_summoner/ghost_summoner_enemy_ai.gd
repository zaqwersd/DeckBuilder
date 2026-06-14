class_name GhostSummonerEnemyAI
extends EnemyActionPicker

const SCAPEGHOST := preload("res://statuses/scapeghost.tres")

var assigned_action_name: StringName = &""
var _statuses_spawned := false


func _ready() -> void:
	super._ready()


func get_action() -> EnemyAction:
	if assigned_action_name.is_empty():
		return null
	return get_node_or_null(String(assigned_action_name)) as EnemyAction


func get_first_conditional_action() -> EnemyAction:
	return null


func _set_enemy(value: Enemy) -> void:
	super._set_enemy(value)
	if value:
		call_deferred("_spawn_starting_statuses")


func _spawn_starting_statuses() -> void:
	if _statuses_spawned or not is_instance_valid(enemy) or enemy.status_handler == null:
		return
	_statuses_spawned = true
	if enemy.status_handler.get_status_by_id("scapeghost") == null:
		var scapeghost := SCAPEGHOST.duplicate() as ScapeghostStatus
		var effect := StatusEffect.new()
		effect.status = scapeghost
		effect.execute([enemy])
