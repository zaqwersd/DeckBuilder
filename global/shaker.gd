extends Node

const META_SHAKE_TWEEN := &"_shaker_active_tween"
const META_HOME_POSITION := &"_shaker_home_position"


func bind_home(thing: Node2D, home: Vector2) -> void:
	if not is_instance_valid(thing):
		return
	thing.set_meta(META_HOME_POSITION, home)


func _home_for(thing: Node2D) -> Vector2:
	if thing.has_meta(META_HOME_POSITION):
		return thing.get_meta(META_HOME_POSITION) as Vector2
	return thing.position


func _kill_active_shake(thing: Node2D) -> void:
	if not thing.has_meta(META_SHAKE_TWEEN):
		return
	var old := thing.get_meta(META_SHAKE_TWEEN) as Tween
	if old != null and old.is_valid():
		old.kill()
	thing.remove_meta(META_SHAKE_TWEEN)


func shake(thing: Node2D, strength: float, duration: float = 0.2) -> void:
	if Events.is_combat_ended() or not is_instance_valid(thing):
		return

	var orig_pos := _home_for(thing)
	thing.position = orig_pos
	_kill_active_shake(thing)

	var shake_count := 10
	var tween := thing.create_tween()
	if tween == null:
		return
	thing.set_meta(META_SHAKE_TWEEN, tween)

	for i in shake_count:
		var shake_offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		var target := orig_pos + strength * shake_offset
		if i % 2 == 0:
			target = orig_pos
		tween.tween_property(thing, "position", target, duration / float(shake_count))
		strength *= 0.75

	tween.tween_property(thing, "position", orig_pos, 0.01)
	tween.finished.connect(
		func() -> void:
			if not is_instance_valid(thing):
				return
			thing.position = orig_pos
			if thing.has_meta(META_SHAKE_TWEEN):
				thing.remove_meta(META_SHAKE_TWEEN),
		CONNECT_ONE_SHOT
	)


func shake_control(ctrl: Control, strength: float = 5.0, duration: float = 0.12) -> void:
	if not is_instance_valid(ctrl):
		return
	var orig_pos := ctrl.position
	var shake_count := 8
	var tween := ctrl.create_tween()
	if tween == null:
		return
	for i in shake_count:
		var shake_offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		var target := orig_pos + strength * shake_offset
		if i % 2 == 0:
			target = orig_pos
		tween.tween_property(ctrl, "position", target, duration / float(shake_count))
		strength *= 0.75
	tween.tween_property(ctrl, "position", orig_pos, 0.01)
