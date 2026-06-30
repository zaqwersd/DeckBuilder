@tool
extends Enemy

@onready var _visual: WaterMonsterEnemyVisual = $Visual


func _resolve_battle_sprite_2d() -> void:
	var body_sprite := get_node_or_null("Visual/Body/Sprite2D") as Sprite2D
	if body_sprite != null:
		sprite_2d = body_sprite


func update_enemy() -> void:
	_resolve_battle_sprite_2d()
	super.update_enemy()
	if is_instance_valid(_visual):
		_visual.apply_shallows_environment_tint()


func refresh_editor_battle_preview() -> void:
	if not Engine.is_editor_hint():
		return
	_resolve_battle_sprite_2d()
	super.refresh_editor_battle_preview()


func _sync_hitbox_to_sprite() -> void:
	if _hitbox_locked:
		return
	if not is_instance_valid(collision_shape_2d) or not is_instance_valid(sprite_2d) or sprite_2d.texture == null:
		return
	var r_sprite := _sprite_local_bounds_for_hitbox()
	var xf := global_transform.affine_inverse() * sprite_2d.global_transform
	var corners: Array[Vector2] = [
		xf * r_sprite.position,
		xf * (r_sprite.position + Vector2(r_sprite.size.x, 0.0)),
		xf * (r_sprite.position + Vector2(0.0, r_sprite.size.y)),
		xf * (r_sprite.position + r_sprite.size),
	]
	var min_v: Vector2 = corners[0]
	var max_v: Vector2 = corners[0]
	for p in corners:
		min_v = min_v.min(p)
		max_v = max_v.max(p)
	var prev := collision_shape_2d.shape as RectangleShape2D
	if prev == null:
		return
	min_v -= Vector2(HITBOX_PAD_PX, HITBOX_PAD_PX)
	max_v += Vector2(HITBOX_PAD_PX, HITBOX_PAD_PX)
	var new_size := max_v - min_v
	var new_pos := (min_v + max_v) * 0.5
	if prev.size.is_equal_approx(new_size) and collision_shape_2d.position.is_equal_approx(new_pos):
		return
	var rect_shape := prev.duplicate() as RectangleShape2D
	rect_shape.size = new_size
	collision_shape_2d.shape = rect_shape
	collision_shape_2d.position = new_pos
	collision_shape_2d.scale = Vector2.ONE
