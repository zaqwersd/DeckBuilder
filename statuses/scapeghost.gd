class_name ScapeghostStatus
extends Status

const MODIFIER := -0.5

var _host: Enemy
var _dmg_taken_modifier: Modifier


func get_tooltip() -> String:
	return "当场上有幽灵存在时，受到的伤害减少50%。"


func initialize_status(target: Node) -> void:
	if not target is Enemy:
		return
	_host = target as Enemy
	_connect_events()
	_refresh_modifier()


func deactivate_status(_target: Node) -> void:
	_disconnect_events()
	_remove_modifier()


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
	_refresh_modifier()


func _refresh_modifier() -> void:
	if not is_instance_valid(_host) or _host.modifier_handler == null:
		return
	_dmg_taken_modifier = _host.modifier_handler.get_modifier(Modifier.Type.DMG_TAKEN)
	if _dmg_taken_modifier == null:
		return
	if _has_live_spook():
		var value := _dmg_taken_modifier.get_value("scapeghost")
		if not value:
			value = ModifierValue.create_new_modifier("scapeghost", ModifierValue.Type.PERCENT_BASED)
			value.percent_value = MODIFIER
			_dmg_taken_modifier.add_new_value(value)
	else:
		_dmg_taken_modifier.remove_value("scapeghost")
	status_changed.emit()


func _remove_modifier() -> void:
	if _dmg_taken_modifier:
		_dmg_taken_modifier.remove_value("scapeghost")


func _has_live_spook() -> bool:
	if not is_instance_valid(_host):
		return false
	var handler := _host.get_parent() as EnemyHandler
	if handler == null:
		return false
	return handler.count_live_spooks() > 0


static func get_on_enemy(enemy: Enemy) -> ScapeghostStatus:
	if enemy == null or enemy.status_handler == null:
		return null
	return enemy.status_handler.get_status_by_id("scapeghost") as ScapeghostStatus
