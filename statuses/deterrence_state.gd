class_name DeterrenceStatus
extends Status

const MUSCLE_STATUS := preload("res://statuses/strength.tres")


func get_tooltip() -> String:
	return tooltip % format_counter_for_tooltip(stacks)


func apply_status(target: Node) -> void:
	if not is_instance_valid(target) or not (target is Player):
		status_applied.emit(self)
		return
	var player := target as Player
	_grant_strength(player)
	var damage := _current_strength(player)
	if damage > 0:
		var effect := DamageEffect.create_fixed(damage)
		effect.execute(_alive_enemies(player.get_tree()))
	status_applied.emit(self)


func _grant_strength(player: Player) -> void:
	if player.status_handler == null or stacks <= 0:
		return
	var muscle := MUSCLE_STATUS.duplicate() as MuscleStatus
	if muscle == null:
		return
	muscle.stacks = stacks
	player.status_handler.add_status(muscle)


func _current_strength(player: Player) -> int:
	if player == null or player.status_handler == null:
		return 0
	var muscle := player.status_handler.get_status_by_id("muscle") as MuscleStatus
	return maxi(0, muscle.stacks if muscle else 0)


func _alive_enemies(tree: SceneTree) -> Array[Node]:
	var out: Array[Node] = []
	if tree == null:
		return out
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or not (node is Enemy):
			continue
		var enemy := node as Enemy
		if enemy.stats != null and enemy.stats.health > 0:
			out.append(enemy)
	return out