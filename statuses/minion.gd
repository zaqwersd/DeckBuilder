class_name MinionStatus
extends Status

var _host: Enemy
var _master: Enemy
var _master_display_name: String = ""


func bind_master(master: Enemy) -> void:
	_master = master
	_master_display_name = ""
	if master != null and master.stats is EnemyStats:
		_master_display_name = (master.stats as EnemyStats).get_display_name()
	if _master_display_name.is_empty():
		_master_display_name = "幽灵召唤师"


func get_tooltip() -> String:
	var name_bb := "[color=%s]%s[/color]" % [CardUpgradeUiColors.BB_VALUE, _master_display_name]
	return "当%s死亡时，自己也会死亡。" % name_bb


func initialize_status(target: Node) -> void:
	if not target is Enemy:
		return
	_host = target as Enemy
	_connect_events()


func deactivate_status(_target: Node) -> void:
	_disconnect_events()


func apply_status(_target: Node) -> void:
	status_applied.emit(self)


func _connect_events() -> void:
	if not Events.enemy_died.is_connected(_on_enemy_died):
		Events.enemy_died.connect(_on_enemy_died)


func _disconnect_events() -> void:
	if Events.enemy_died.is_connected(_on_enemy_died):
		Events.enemy_died.disconnect(_on_enemy_died)


func _on_enemy_died(dead: Enemy) -> void:
	if not is_instance_valid(_master) or dead != _master:
		return
	if not is_instance_valid(_host) or not is_instance_valid(_host.stats):
		return
	if _host.stats.health <= 0:
		return
	var lethal := _host.stats.health + _host.stats.block
	_host.take_damage(lethal, Modifier.Type.DMG_TAKEN)


static func get_on_enemy(enemy: Enemy) -> MinionStatus:
	if enemy == null or enemy.status_handler == null:
		return null
	return enemy.status_handler.get_status_by_id("minion") as MinionStatus
