class_name ThunderStatus
extends Status

func get_tooltip() -> String:
	return tooltip % format_counter_for_tooltip(stacks)


func initialize_status(target: Node) -> void:
	if not Events.card_played.is_connected(_on_card_played):
		Events.card_played.connect(_on_card_played.bind(target))


func deactivate_status(_target: Node) -> void:
	for c in Events.card_played.get_connections():
		var callable: Callable = c["callable"]
		if callable.get_object() == self:
			Events.card_played.disconnect(callable)


func _on_card_played(_card: Card, host: Node) -> void:
	if stacks <= 0 or Events.is_combat_ended():
		return
	if not is_instance_valid(host):
		return
	var enemy := host as Enemy
	if enemy == null or enemy.stats == null or enemy.stats.health <= 0:
		return
	var player := enemy.get_tree().get_first_node_in_group("battle_player") as Player
	if player == null:
		return
	var dmg := DamageEffect.create_fixed(stacks)
	dmg.execute([player])