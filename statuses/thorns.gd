class_name ThornsStatus
extends Status

func get_tooltip() -> String:
	return tooltip % format_counter_for_tooltip(stacks)


func initialize_status(target: Node) -> void:
	if not Events.player_attack_hit_enemy.is_connected(_on_player_attack_hit_enemy):
		Events.player_attack_hit_enemy.connect(_on_player_attack_hit_enemy.bind(target))


func deactivate_status(_target: Node) -> void:
	# 多个敌人可能都有荆棘，同一个状态实例只断开自己绑定的 Callable。
	for c in Events.player_attack_hit_enemy.get_connections():
		var callable: Callable = c["callable"]
		if callable.get_object() == self:
			Events.player_attack_hit_enemy.disconnect(callable)


func _on_player_attack_hit_enemy(victim: Enemy, _amount: int, host: Node) -> void:
	if stacks <= 0 or Events.is_combat_ended():
		return
	if victim != host or not is_instance_valid(host):
		return
	var player := (host as Node).get_tree().get_first_node_in_group("battle_player") as Player
	if player == null:
		return
	var dmg := DamageEffect.create_fixed(stacks)
	dmg.execute([player])