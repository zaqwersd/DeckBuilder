extends Node


func shake(thing: Node2D, strength: float, duration: float = 0.2) -> void:
	if Events.is_combat_ended() or not is_instance_valid(thing):
		return

	var orig_pos := thing.position
	var shake_count := 10
	## 挂在被抖动节点上：节点释放时 tween 自动终止，避免 lambda 捕获已释放对象。
	var tween := thing.create_tween()
	if tween == null:
		return

	for i in shake_count:
		var shake_offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		var target := orig_pos + strength * shake_offset
		if i % 2 == 0:
			target = orig_pos
		tween.tween_property(thing, "position", target, duration / float(shake_count))
		strength *= 0.75

	tween.tween_property(thing, "position", orig_pos, 0.01)


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
