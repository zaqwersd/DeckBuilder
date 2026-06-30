class_name EnemyTargeting


static func get_card_targeting_rect_global(enemy: Enemy) -> Rect2:
	if not is_instance_valid(enemy):
		return Rect2()
	return enemy.get_card_targeting_rect_global()


static func is_mouse_over_targeting_rect(enemy: Enemy, mouse_global: Vector2) -> bool:
	var rect := get_card_targeting_rect_global(enemy)
	return rect.has_area() and rect.has_point(mouse_global)


static func pick_enemy_under_mouse(mouse_global: Vector2, tree: SceneTree) -> Enemy:
	var best: Enemy = null
	var best_d2 := INF
	for node in tree.get_nodes_in_group("enemies"):
		if not node is Enemy:
			continue
		var e := node as Enemy
		if not is_instance_valid(e) or not e.is_inside_tree():
			continue
		if not is_instance_valid(e.stats) or e.stats.health <= 0:
			continue
		if not is_mouse_over_targeting_rect(e, mouse_global):
			continue
		var rect := get_card_targeting_rect_global(e)
		var d2 := rect.get_center().distance_squared_to(mouse_global)
		if d2 < best_d2:
			best_d2 = d2
			best = e
	return best


static func clear_all_card_targeting_feedback(tree: SceneTree) -> void:
	if tree == null:
		return
	for node in tree.get_nodes_in_group("enemies"):
		if node is Enemy:
			(node as Enemy).set_card_targeting_feedback(false, false, Vector2.ZERO)


## 存活敌人稳定排序（槽位 → x → 实例 id），供鱼骨等随机目标与 RNG 序号一致。
static func list_alive_enemies_sorted(tree: SceneTree) -> Array[Enemy]:
	var alive: Array[Enemy] = []
	if tree == null:
		return alive
	for node in tree.get_nodes_in_group("enemies"):
		if not node is Enemy:
			continue
		var enemy := node as Enemy
		if not is_instance_valid(enemy) or not is_instance_valid(enemy.stats):
			continue
		if enemy.stats.health <= 0:
			continue
		alive.append(enemy)
	alive.sort_custom(compare_enemies_stable)
	return alive


static func compare_enemies_stable(a: Enemy, b: Enemy) -> bool:
	return _alive_enemy_sort_key(a) < _alive_enemy_sort_key(b)


static func _alive_enemy_sort_key(enemy: Enemy) -> String:
	var slot := 9999
	if enemy.has_meta(&"skeleton_slot"):
		slot = int(enemy.get_meta(&"skeleton_slot"))
	elif enemy.has_meta(&"spook_slot"):
		slot = int(enemy.get_meta(&"spook_slot"))
	var stable_id := ""
	if is_instance_valid(enemy.stats):
		var stats_id: Variant = enemy.stats.get(&"id")
		if stats_id is String and not (stats_id as String).is_empty():
			stable_id = stats_id as String
		elif not enemy.stats.resource_path.is_empty():
			stable_id = enemy.stats.resource_path
	if stable_id.is_empty():
		stable_id = "enemy"
	return "%04d|%06d|%s" % [slot, int(enemy.position.x), stable_id]
