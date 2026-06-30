class_name TooltipHoverUtil
extends RefCounted

## 从 Run 获取全局 GameTooltip（商店/地图等）。
static func get_run_game_tooltip(tree: SceneTree) -> GameTooltip:
	if tree == null:
		return null
	var run_node := tree.get_first_node_in_group("run")
	if run_node is Run and is_instance_valid((run_node as Run).game_tooltip):
		return (run_node as Run).game_tooltip
	return null


## 购买/售出等须立刻关闭，不能等悬停延迟判定。
static func hide_immediate(tree: SceneTree) -> void:
	var tip := get_run_game_tooltip(tree)
	if tip:
		tip.hide_tooltip_immediate()


static func collect_sibling_controls(owner: Control, type_class: Variant) -> Array[Control]:
	var out: Array[Control] = []
	var parent := owner.get_parent()
	if parent == null:
		return out
	for child in parent.get_children():
		if child is Control and child != owner and is_instance_of(child, type_class):
			out.append(child as Control)
	return out


static func collect_controls_under_node(root: Node, type_class: Variant) -> Array[Control]:
	var out: Array[Control] = []
	if root == null:
		return out
	_gather_controls_under(root, type_class, out)
	return out


static func _gather_controls_under(node: Node, type_class: Variant, out: Array[Control]) -> void:
	if node is Control and is_instance_of(node, type_class):
		out.append(node as Control)
	for child in node.get_children():
		_gather_controls_under(child, type_class, out)


static func pointer_over_control_or_peers(
	screen_pos: Vector2,
	self_control: Control,
	peer_controls: Array[Control]
) -> bool:
	if CombatPointer.control_has_screen_point(self_control, screen_pos):
		return true
	return pointer_over_any_controls(screen_pos, peer_controls)


static func pointer_over_any_controls(screen_pos: Vector2, controls: Array) -> bool:
	for c: Variant in controls:
		if c is Control and is_instance_valid(c) and CombatPointer.control_has_screen_point(c, screen_pos):
			return true
	return false
