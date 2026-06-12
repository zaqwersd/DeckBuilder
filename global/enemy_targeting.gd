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
