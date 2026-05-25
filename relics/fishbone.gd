extends Relic

@export var bonus_damage := 1

var relic_ui: RelicUI


func initialize_relic(owner: RelicUI) -> void:
	relic_ui = owner
	Events.player_dealt_attack_damage_to_enemy.connect(_on_player_dealt_attack_damage_to_enemy)


func deactivate_relic(_owner: RelicUI) -> void:
	if Events.player_dealt_attack_damage_to_enemy.is_connected(_on_player_dealt_attack_damage_to_enemy):
		Events.player_dealt_attack_damage_to_enemy.disconnect(_on_player_dealt_attack_damage_to_enemy)


func _on_player_dealt_attack_damage_to_enemy(_victim: Enemy, _amount: int) -> void:
	if Events.is_combat_ended() or not is_instance_valid(relic_ui):
		return
	var tree := relic_ui.get_tree()
	if tree == null:
		return
	var alive := _get_alive_enemies(tree)
	if alive.is_empty():
		return
	var target: Node = RNG.array_pick_random(alive) as Node
	if target == null:
		return
	var effect := DamageEffect.new()
	effect.amount = bonus_damage
	effect.receiver_modifier_type = Modifier.Type.NO_MODIFIER
	effect.execute([target])
	relic_ui.flash()


func _get_alive_enemies(tree: SceneTree) -> Array[Node]:
	var alive: Array[Node] = []
	for enemy in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if enemy.get("stats") == null:
			continue
		var enemy_stats: Stats = enemy.get("stats") as Stats
		if enemy_stats != null and enemy_stats.health > 0:
			alive.append(enemy)
	return alive
