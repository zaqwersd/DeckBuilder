class_name PilgrimAI
extends EnemyActionPicker

const _INTENT_COORDINATOR := preload("res://enemies/pilgrim/pilgrim_intent_coordinator.gd")
const SINS_STATUS := preload("res://statuses/sins.tres")

var _last_action_name: String = ""
var assigned_action_name: StringName = &""
var _statuses_spawned := false


func get_action() -> EnemyAction:
	if assigned_action_name.is_empty():
		return null
	var path := NodePath(String(assigned_action_name))
	if not has_node(path):
		return null
	return get_node(path) as EnemyAction


func get_last_intent_id() -> int:
	return _INTENT_COORDINATOR.action_name_to_intent_id(_last_action_name)


func _ready() -> void:
	super._ready()
	_spawn_starting_statuses()
	if not Events.enemy_action_completed.is_connected(_on_enemy_action_completed):
		Events.enemy_action_completed.connect(_on_enemy_action_completed)


func _set_enemy(value: Enemy) -> void:
	super._set_enemy(value)
	if value:
		_spawn_starting_statuses()


func _spawn_starting_statuses() -> void:
	if not is_instance_valid(enemy):
		return
	if enemy.status_handler == null:
		call_deferred("_spawn_starting_statuses")
		return
	var tree := enemy.get_tree()
	var player := tree.get_first_node_in_group("player") as Player if tree else null
	if player == null and tree:
		player = tree.get_first_node_in_group("battle_player") as Player
	var existing := SinsStatus.get_on_enemy(enemy)
	if existing != null:
		SinsStatus.prepare_fresh_on_enemy(existing)
		if not _statuses_spawned:
			_statuses_spawned = true
			_play_sins_insert_animations(SinsStatus.consume_pending_draws(existing, player), player)
		return
	if _statuses_spawned:
		return
	_statuses_spawned = true
	var sins := SINS_STATUS.duplicate() as SinsStatus
	SinsStatus.prepare_fresh_on_enemy(sins)
	var effect := StatusEffect.new()
	effect.status = sins
	effect.execute([enemy])
	_play_sins_insert_animations(
		SinsStatus.consume_pending_draws(SinsStatus.get_on_enemy(enemy), player), player
	)


func _play_sins_insert_animations(profanes: Array[Card], player: Player) -> void:
	if profanes.is_empty() or player == null:
		return
	await SinsStatus.play_insert_animations_for_cards(profanes, player)


func _on_enemy_action_completed(completed_enemy: Enemy) -> void:
	if not is_instance_valid(enemy) or completed_enemy != enemy:
		return
	if not enemy.current_action:
		return
	_last_action_name = enemy.current_action.name


func _exit_tree() -> void:
	if Events.enemy_action_completed.is_connected(_on_enemy_action_completed):
		Events.enemy_action_completed.disconnect(_on_enemy_action_completed)
