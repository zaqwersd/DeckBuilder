class_name CombatPointer
extends RefCounted

## 屏幕坐标下的鼠标位置（与 Control 命中检测一致）。
static func screen_mouse(viewport: Viewport) -> Vector2:
	if viewport == null:
		return Vector2.ZERO
	return viewport.get_mouse_position()


## 战斗内挂在 Node2D 下的 Control：用 canvas 变换 + global_transform_with_canvas 做点测。
static func control_has_screen_point(control: Control, screen_pos: Vector2, padding: float = 0.0) -> bool:
	if not is_instance_valid(control) or not control.is_inside_tree():
		return false
	var viewport := control.get_viewport()
	if viewport == null:
		return false
	var canvas_pos: Vector2 = viewport.get_canvas_transform().affine_inverse() * screen_pos
	var local: Vector2 = control.get_global_transform_with_canvas().affine_inverse() * canvas_pos
	var sz := control.size
	if sz.x < 1.0 or sz.y < 1.0:
		sz = control.get_combined_minimum_size()
	var rect := Rect2(Vector2.ZERO, sz)
	if padding > 0.0:
		rect = rect.grow(padding)
	return rect.has_point(local)


## Area2D / Node2D 碰撞体：world_pos 为 get_global_mouse_position() 等同的画布坐标。
static func node2d_shape_has_world_point(
	node: Node2D,
	collision_shape: CollisionShape2D,
	world_pos: Vector2
) -> bool:
	if not is_instance_valid(node) or not is_instance_valid(collision_shape):
		return false
	if collision_shape.shape == null:
		return false
	var circle_shape := collision_shape.shape as CircleShape2D
	if circle_shape != null:
		var inv_circle := collision_shape.global_transform.affine_inverse()
		var local_circle: Vector2 = inv_circle * world_pos
		return local_circle.length_squared() <= circle_shape.radius * circle_shape.radius
	var rect_shape := collision_shape.shape as RectangleShape2D
	if rect_shape == null:
		return false
	var inv := collision_shape.global_transform.affine_inverse()
	var local_p: Vector2 = inv * world_pos
	return Rect2(-rect_shape.size * 0.5, rect_shape.size).has_point(local_p)
