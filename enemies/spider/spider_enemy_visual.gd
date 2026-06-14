class_name SpiderEnemyVisual
extends Node2D

const LINE_WIDTH := 2.0
const OFF_SCREEN_MARGIN_PX := 64.0
const BOB_RANGE_PX := 10.0
const BOB_SEGMENT_SEC := 0.85

var _line: Line2D


static func attach_to(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return
	var sprite_2d := enemy.get_node_or_null("Sprite2D") as Sprite2D
	if not is_instance_valid(sprite_2d):
		return
	var existing := enemy.get_node_or_null("SpiderVisualRig") as SpiderEnemyVisual
	if existing != null:
		if existing._line != null:
			return
		existing.queue_free()
	var rig := SpiderEnemyVisual.new()
	rig.name = "SpiderVisualRig"
	enemy.add_child(rig)
	enemy.move_child(rig, 0)
	rig.call_deferred("_build", sprite_2d)


func _build(sprite: Sprite2D) -> void:
	if not is_instance_valid(sprite):
		return
	sprite.reparent(self)
	sprite.position = Vector2.ZERO
	sprite.z_index = 1

	_line = Line2D.new()
	_line.name = "SilkLine"
	_line.width = LINE_WIDTH
	_line.default_color = Color.WHITE
	_line.modulate = Color.WHITE
	_line.antialiased = false
	_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_line.z_index = 0
	add_child(_line)
	move_child(_line, 0)

	set_process(true)
	_update_line_points()

	position.y = RNG.instance.randf_range(-BOB_RANGE_PX, BOB_RANGE_PX)
	if is_inside_tree():
		_queue_bob_leg()
	else:
		tree_entered.connect(_queue_bob_leg, CONNECT_ONE_SHOT)


func _process(_delta: float) -> void:
	_update_line_points()


func _update_line_points() -> void:
	if _line == null or not is_inside_tree():
		return
	var end_y := _screen_top_local_y()
	_line.points = PackedVector2Array([Vector2.ZERO, Vector2(0.0, end_y)])


func _screen_top_local_y() -> float:
	var viewport := get_viewport()
	if viewport == null:
		return -1024.0
	var visible := viewport.get_visible_rect()
	var anchor_global := Vector2(global_position.x, visible.position.y - OFF_SCREEN_MARGIN_PX)
	return to_local(anchor_global).y


func _queue_bob_leg() -> void:
	if not is_inside_tree():
		return
	var target_y := RNG.instance.randf_range(-BOB_RANGE_PX, BOB_RANGE_PX)
	if absf(target_y - position.y) < 2.0:
		target_y = clampf(position.y + BOB_RANGE_PX * 0.5, -BOB_RANGE_PX, BOB_RANGE_PX)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position:y", target_y, BOB_SEGMENT_SEC)
	tween.finished.connect(_queue_bob_leg)
