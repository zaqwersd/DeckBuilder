class_name SpookEnemyVisual
extends Node2D

const BOB_RANGE_PX := 9.0
const BOB_SEGMENT_SEC := 0.85


static func attach_to(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return
	var sprite_2d := enemy.get_node_or_null("Sprite2D") as Sprite2D
	if not is_instance_valid(sprite_2d):
		return
	var existing := enemy.get_node_or_null("SpookVisualRig") as SpookEnemyVisual
	if existing != null:
		return
	var rig := SpookEnemyVisual.new()
	rig.name = "SpookVisualRig"
	enemy.add_child(rig)
	enemy.move_child(rig, 0)
	rig.call_deferred("_build", sprite_2d)


func _build(sprite: Sprite2D) -> void:
	if not is_instance_valid(sprite):
		return
	sprite.reparent(self)
	sprite.position = Vector2.ZERO
	position.y = RNG.instance.randf_range(-BOB_RANGE_PX, BOB_RANGE_PX)
	if is_inside_tree():
		_queue_bob_leg()
	else:
		tree_entered.connect(_queue_bob_leg, CONNECT_ONE_SHOT)


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
