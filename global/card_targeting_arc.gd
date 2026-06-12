class_name CardTargetingArc

const COLOR_DEFAULT := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_VALID := Color(1.0, 0.25, 0.2, 1.0)
## `arrow.png` 贴图尖端朝上（局部 -Y）。
const TEXTURE_TIP_AXIS := Vector2.UP


static func apply_visual(
	arc: Line2D,
	head: Sprite2D,
	points: PackedVector2Array,
	has_valid_target: bool,
) -> void:
	var color := COLOR_VALID if has_valid_target else COLOR_DEFAULT
	arc.default_color = color
	if points.is_empty():
		arc.clear_points()
		if is_instance_valid(head):
			head.hide()
		return
	arc.points = points
	if not is_instance_valid(head):
		return
	if points.size() < 2:
		head.hide()
		return
	head.show()
	head.modulate = color
	var end: Vector2 = points[points.size() - 1]
	var prev: Vector2 = points[points.size() - 2]
	var dir := end - prev
	if dir.length_squared() < 0.01:
		dir = Vector2.RIGHT
	head.position = end
	head.rotation = dir.angle() - TEXTURE_TIP_AXIS.angle()


static func clear_visual(arc: Line2D, head: Sprite2D) -> void:
	if is_instance_valid(arc):
		arc.clear_points()
		arc.default_color = COLOR_DEFAULT
	if is_instance_valid(head):
		head.hide()
		head.modulate = COLOR_DEFAULT
