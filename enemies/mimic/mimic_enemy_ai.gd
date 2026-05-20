class_name MimicEnemyAI
extends EnemyActionPicker

const ALERT := preload("res://statuses/alert.tres")
const MIMIC_AWAKENING_SFX := preload("res://art/mimic_awakening.ogg")
const INITIAL_WAKE_TURNS := 3
const SLEEP_ACTION_NAME := "MimicSleep"
const WAKE_STRIKE_NAME := "MimicWakeStrike20"
const STRIKE8_NAME := "MimicStrike8Exposed"
const STRIKE16_NAME := "MimicStrike16"

var _is_awake := false
var _pending_wake_strike := false
var _alert_spawned := false
var _last_action_name: String = ""
var _consecutive_same: int = 0


func _ready() -> void:
	super._ready()
	if not Events.enemy_action_completed.is_connected(_on_enemy_action_completed):
		Events.enemy_action_completed.connect(_on_enemy_action_completed)


func _exit_tree() -> void:
	if Events.enemy_action_completed.is_connected(_on_enemy_action_completed):
		Events.enemy_action_completed.disconnect(_on_enemy_action_completed)


func _set_enemy(value: Enemy) -> void:
	super._set_enemy(value)
	if value and not _alert_spawned:
		_alert_spawned = true
		call_deferred("_spawn_alert_status")


func _spawn_alert_status() -> void:
	if not is_instance_valid(enemy) or not enemy.status_handler:
		return
	if enemy.status_handler.get_status_by_id("alert") != null:
		return
	var alert := ALERT.duplicate() as AlertStatus
	alert.turns_until_wake = INITIAL_WAKE_TURNS
	enemy.status_handler.add_status(alert)


func get_action() -> EnemyAction:
	if not _is_awake:
		return get_node_or_null(SLEEP_ACTION_NAME) as EnemyAction
	if _pending_wake_strike:
		return get_node_or_null(WAKE_STRIKE_NAME) as EnemyAction
	return _pick_awake_action()


func get_first_conditional_action() -> EnemyAction:
	return null


func wake_from_sleep() -> void:
	if _is_awake or not is_instance_valid(enemy):
		return
	SFXPlayer.play(MIMIC_AWAKENING_SFX)
	_is_awake = true
	_pending_wake_strike = true
	if enemy.status_handler:
		enemy.status_handler.remove_status_by_id("alert")
	var mimic_stats := enemy.stats as MimicEnemyStats
	if mimic_stats and mimic_stats.awake_art:
		enemy.set_display_texture(mimic_stats.awake_art)
	enemy.current_action = null
	enemy.update_action()


func _pick_awake_action() -> EnemyAction:
	var pool: Array[EnemyAction] = []
	for action_name in [STRIKE8_NAME, STRIKE16_NAME]:
		var action := get_node_or_null(action_name) as EnemyAction
		if action == null:
			continue
		if _would_be_third_repeat(action.name):
			continue
		pool.append(action)
	
	if pool.is_empty():
		for action_name in [STRIKE8_NAME, STRIKE16_NAME]:
			var action := get_node_or_null(action_name) as EnemyAction
			if action:
				pool.append(action)
	
	return RNG.array_pick_random(pool) as EnemyAction


func _would_be_third_repeat(action_name: String) -> bool:
	return _last_action_name == action_name and _consecutive_same >= 2


func _tick_alert_after_sleep() -> void:
	if _is_awake or not is_instance_valid(enemy) or not enemy.status_handler:
		return
	var alert := enemy.status_handler.get_status_by_id("alert") as AlertStatus
	if alert == null:
		return
	alert.tick_sleep_turn()
	if alert.turns_until_wake <= 0:
		wake_from_sleep()


func _on_enemy_action_completed(completed_enemy: Enemy) -> void:
	if not is_instance_valid(enemy) or completed_enemy != enemy:
		return
	if not enemy.current_action:
		return
	var finished_name := enemy.current_action.name
	if finished_name == SLEEP_ACTION_NAME:
		_tick_alert_after_sleep()
		return
	if finished_name == WAKE_STRIKE_NAME:
		_pending_wake_strike = false
		return
	if _last_action_name == finished_name:
		_consecutive_same += 1
	else:
		_last_action_name = finished_name
		_consecutive_same = 1
