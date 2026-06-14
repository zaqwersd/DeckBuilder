class_name ShellMechEnemyAI
extends EnemyActionPicker

const ACTION_STRIKE := &"Strike21"
const ACTION_BLOCK := &"Block16"

const ARTIFACT := preload("res://statuses/artifact.tres")
const HARD_SHELL := preload("res://statuses/hard_shell.tres")

var _last_action_name: StringName = &""
var _statuses_spawned := false


func _ready() -> void:
	super._ready()
	if not Events.enemy_action_completed.is_connected(_on_enemy_action_completed):
		Events.enemy_action_completed.connect(_on_enemy_action_completed)


func _exit_tree() -> void:
	if Events.enemy_action_completed.is_connected(_on_enemy_action_completed):
		Events.enemy_action_completed.disconnect(_on_enemy_action_completed)


func _set_enemy(value: Enemy) -> void:
	super._set_enemy(value)
	if value:
		call_deferred("_spawn_starting_statuses")


func _spawn_starting_statuses() -> void:
	if _statuses_spawned or not is_instance_valid(enemy) or enemy.status_handler == null:
		return
	_statuses_spawned = true
	
	if enemy.status_handler.get_status_by_id("artifact") == null:
		var artifact := ARTIFACT.duplicate() as ArtifactStatus
		artifact.set_stacks(2)
		var artifact_effect := StatusEffect.new()
		artifact_effect.status = artifact
		artifact_effect.execute([enemy])
	
	if enemy.status_handler.get_status_by_id("hard_shell") == null:
		var hard_shell := HARD_SHELL.duplicate() as HardShellStatus
		var shell_effect := StatusEffect.new()
		shell_effect.status = hard_shell
		shell_effect.execute([enemy])
	
	var rig := enemy.get_node_or_null("ShellMechVisualRig") as ShellMechEnemyVisual
	if rig != null:
		rig.call_deferred("_connect_hard_shell_signal")


func get_action() -> EnemyAction:
	var strike := get_node_or_null(String(ACTION_STRIKE)) as EnemyAction
	var block := get_node_or_null(String(ACTION_BLOCK)) as EnemyAction
	if strike == null or block == null:
		return strike if strike else block
	
	if _last_action_name.is_empty():
		return RNG.array_pick_random([strike, block]) as EnemyAction
	
	if _last_action_name == ACTION_STRIKE:
		return block
	return strike


func _on_enemy_action_completed(completed_enemy: Enemy) -> void:
	if not is_instance_valid(enemy) or completed_enemy != enemy:
		return
	if not enemy.current_action:
		return
	_last_action_name = StringName(enemy.current_action.name)
