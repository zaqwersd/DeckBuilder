class_name GhostSummonerEnemyVisual
extends Node2D

const FRAME_IDLE := preload("res://art/ghost_summoner1.png")
const FRAME_BLINK := preload("res://art/ghost_summoner2.png")
const BLINK_DURATION := 0.1

var _sprite: Sprite2D
var _blink_timer: Timer


static func attach_to(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return
	var sprite_2d := enemy.get_node_or_null("Sprite2D") as Sprite2D
	if not is_instance_valid(sprite_2d):
		return
	var existing := enemy.get_node_or_null("GhostSummonerVisualRig") as GhostSummonerEnemyVisual
	if existing != null:
		return
	var rig := GhostSummonerEnemyVisual.new()
	rig.name = "GhostSummonerVisualRig"
	enemy.add_child(rig)
	enemy.move_child(rig, 0)
	rig.call_deferred("_build", enemy, sprite_2d)


func _build(enemy: Node, sprite_2d: Sprite2D) -> void:
	if not is_instance_valid(enemy) or not is_instance_valid(sprite_2d):
		return
	_sprite = sprite_2d
	_sprite.reparent(self)
	_sprite.position = Vector2.ZERO
	_sprite.texture = FRAME_IDLE
	_schedule_blink()


func _schedule_blink() -> void:
	if not is_instance_valid(_sprite):
		return
	if _blink_timer == null:
		_blink_timer = Timer.new()
		_blink_timer.one_shot = true
		add_child(_blink_timer)
		_blink_timer.timeout.connect(_on_blink_timer)
	_blink_timer.wait_time = RNG.instance.randf_range(1.0, 2.0)
	_blink_timer.start()


func _on_blink_timer() -> void:
	if not is_instance_valid(_sprite):
		return
	_sprite.texture = FRAME_BLINK
	var tween := create_tween()
	tween.tween_interval(BLINK_DURATION)
	tween.tween_callback(
		func() -> void:
			if is_instance_valid(_sprite):
				_sprite.texture = FRAME_IDLE
			_schedule_blink()
	)
