class_name FloatingCombatNumber
extends Label

const RISE_PX := 140.0
const DURATION := 0.7


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func setup(local_center: Vector2, amount: int, color: Color) -> void:
	text = str(amount)
	add_theme_font_size_override("font_size", 128)
	add_theme_color_override("font_color", color)
	add_theme_constant_override("outline_size", 10)
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.88))
	z_index = 200
	z_as_relative = false
	set_meta("_float_center", local_center)


func _ready() -> void:
	var center: Vector2 = get_meta("_float_center", Vector2.ZERO)
	reset_size()
	await get_tree().process_frame
	var sz := get_minimum_size()
	position = center - sz * 0.5
	var p := get_parent()
	if not p is Node2D:
		queue_free()
		return
	var tw := (p as Node2D).create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", position.y - RISE_PX, DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "modulate:a", 0.0, DURATION * 0.92)
	tw.finished.connect(queue_free)


static func spawn(host: Node2D, local_center: Vector2, amount: int, color: Color) -> void:
	if amount <= 0 or not is_instance_valid(host):
		return
	var n := FloatingCombatNumber.new()
	n.setup(local_center, amount, color)
	host.add_child(n)
