class_name ScapeghostStatus
extends Status

const MODIFIER := -0.5

var _host: Enemy


func get_tooltip() -> String:
	return "When a live spook exists, damage taken is reduced by 50%."


func initialize_status(target: Node) -> void:
	if not target is Enemy:
		return
	_host = target as Enemy
	_connect_events()
	_refresh_modifier(true)


func deactivate_status(_target: Node) -> void:
	_refresh_modifier(true)
	_disconnect_events()


func apply_status(_target: Node) -> void:
	status_applied.emit(self)


func _connect_events() -> void:
	if not Events.enemy_died.is_connected(_on_enemy_died):
		Events.enemy_died.connect(_on_enemy_died)


func _disconnect_events() -> void:
	if Events.enemy_died.is_connected(_on_enemy_died):
		Events.enemy_died.disconnect(_on_enemy_died)
	_remove_modifier()


func _on_enemy_died(_enemy: Enemy) -> void:
	_refresh_modifier(true)


static func is_reduction_active(enemy: Enemy) -> bool:
	if enemy == null or get_on_enemy(enemy) == null:
		return false
	var handler := enemy.get_parent() as EnemyHandler
	if handler == null:
		return false
	return handler.count_live_spooks() > 0


func _refresh_modifier(emit_player_context_changed: bool = false) -> void:
	# Damage is handled in a separate multiplier branch, so we only notify UI.
	status_changed.emit()
	if emit_player_context_changed and not Events.is_player_turn_start_resolving() and not Events.is_combat_ended():
		Events.player_combat_stat_context_changed.emit()


func _remove_modifier() -> void:
	pass


func _has_live_spook() -> bool:
	return is_reduction_active(_host)


static func get_on_enemy(enemy: Enemy) -> ScapeghostStatus:
	if enemy == null or enemy.status_handler == null:
		return null
	return enemy.status_handler.get_status_by_id("scapeghost") as ScapeghostStatus


## Refresh preview state when the live spook count changes.
static func sync_preview_damage_taken_modifier(enemy: Enemy) -> void:
	var st := get_on_enemy(enemy)
	if st != null:
		st._refresh_modifier(false)


static func get_damage_taken_multiplier(enemy: Enemy) -> float:
	if is_reduction_active(enemy):
		return 1.0 + MODIFIER
	return 1.0
