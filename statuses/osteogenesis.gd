class_name OsteogenesisStatus
extends Status

const MAX_LITTLE_SKELTONS := 5

var _host_enemy: Enemy


func get_tooltip() -> String:
	return tooltip


func initialize_status(target: Node) -> void:
	_host_enemy = target as Enemy
	if not Events.enemy_dealt_unblocked_damage_to_player.is_connected(_on_enemy_dealt_unblocked_damage):
		Events.enemy_dealt_unblocked_damage_to_player.connect(_on_enemy_dealt_unblocked_damage)


func deactivate_status(_target: Node) -> void:
	if Events.enemy_dealt_unblocked_damage_to_player.is_connected(_on_enemy_dealt_unblocked_damage):
		Events.enemy_dealt_unblocked_damage_to_player.disconnect(_on_enemy_dealt_unblocked_damage)
	_host_enemy = null


func _on_enemy_dealt_unblocked_damage(dealer: Enemy, amount: int) -> void:
	if amount <= 0 or dealer == null or not is_instance_valid(_host_enemy):
		return
	if dealer != _host_enemy:
		return
	var handler := _get_enemy_handler()
	if handler == null:
		return
	handler.try_spawn_little_skelton_from_osteogenesis(_host_enemy)


func _get_enemy_handler() -> EnemyHandler:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group("enemy_handler") as EnemyHandler
