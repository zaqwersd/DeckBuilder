extends Card

const _PER_HIT_DELAY_SEC := 0.2


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["hits"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	match track_id:
		"hits":
			return PackedInt32Array([3, 4])
		_:
			return PackedInt32Array()


func get_upgrade_pick_description_bbcode() -> String:
	var h := get_upgrade_value_at("hits")
	return "[center]随机对敌人造成3点伤害%s次。[/center]" % bbcode_upgrade_pick_digit("hits", h)


func _per_hit_damage() -> int:
	return 3


func _hit_count() -> int:
	return get_upgrade_value_at("hits")


func get_default_tooltip() -> String:
	return "随机对敌人造成%s点伤害%s次。" % [str(_per_hit_damage()), str(_hit_count())]


func get_updated_tooltip(
	player_modifiers: ModifierHandler, enemy_modifiers: ModifierHandler, combat_player: Node = null
) -> String:
	var d_base := _per_hit_damage()
	var dmg_bb := bbcode_for_modified_number_with_upgrade_hint(
		compute_attack_damage_dealt(d_base, player_modifiers, enemy_modifiers, combat_player),
		d_base,
		true
	)
	var h_base := _hit_count()
	var hits_bb := bbcode_for_modified_number_with_upgrade_hint(
		h_base, h_base, is_upgrade_track_maxed("hits")
	)
	return "[center]随机对敌人造成%s点伤害%s次。[/center]" % [dmg_bb, hits_bb]


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
	var per := resolve_attack_damage_dealt(
		_per_hit_damage(), modifiers, _get_combat_player_for_effects(targets)
	)
	var n := _hit_count()
	var tree: SceneTree = null
	for t in targets:
		if is_instance_valid(t) and t.is_inside_tree():
			tree = t.get_tree()
			break
	if tree == null:
		tree = Engine.get_main_loop() as SceneTree
	
	for i in range(n):
		# 每段攻击前重新获取存活敌人并随机选择目标
		var alive_enemies := _get_alive_enemies(tree)
		if alive_enemies.is_empty():
			break
		
		var target: Node = RNG.array_pick_random(alive_enemies)
		if target == null:
			break
		
		var damage_effect := DamageEffect.new()
		damage_effect.amount = per
		damage_effect.sound = sound
		damage_effect.execute([target])
		
		if i < n - 1 and tree != null:
			await tree.create_timer(_PER_HIT_DELAY_SEC).timeout


## 获取当前存活的敌人列表
func _get_alive_enemies(tree: SceneTree) -> Array[Node]:
	if tree == null:
		return []
	var all_enemies := tree.get_nodes_in_group("enemies")
	var alive: Array[Node] = []
	for enemy in all_enemies:
		if not is_instance_valid(enemy):
			continue
		# 检查敌人是否有 stats 属性且 health > 0
		if enemy.get("stats") != null:
			var stats = enemy.get("stats")
			if stats.get("health") != null and stats.get("health") > 0:
				alive.append(enemy)
	return alive
