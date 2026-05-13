class_name FloatingCombatNumber
extends Label

const RISE_PX := 140.0
const DURATION := 0.7


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER


## `anchor_in_host_space`：在 `host` 局部坐标系中的飘字锚点（通常为精灵顶/中心附近）。
func setup(host: Node2D, anchor_in_host_space: Vector2, amount: int, color: Color) -> void:
	text = str(amount)
	add_theme_font_size_override("font_size", 128)
	add_theme_color_override("font_color", color)
	add_theme_constant_override("outline_size", 10)
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.88))
	z_index = 200
	z_as_relative = false
	set_meta("_float_host", host)
	set_meta("_float_anchor_host", anchor_in_host_space)
	# 入树首帧位置为 (0,0)，须等 process_frame 后再对齐宿主；此前保持隐藏避免左上角闪一下。
	visible = false


func _ready() -> void:
	var host: Node2D = get_meta("_float_host", null) as Node2D
	var anchor_host: Vector2 = get_meta("_float_anchor_host", Vector2.ZERO)
	if not is_instance_valid(host):
		queue_free()
		return
	reset_size()
	await get_tree().process_frame
	if not is_instance_valid(host):
		queue_free()
		return
	var sz := get_minimum_size()
	var anchor_global := host.to_global(anchor_host)
	global_position = anchor_global - sz * 0.5
	visible = true
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "global_position:y", global_position.y - RISE_PX, DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "modulate:a", 0.0, DURATION * 0.92)
	tw.finished.connect(queue_free)


static func spawn(host: Node2D, local_center: Vector2, amount: int, color: Color) -> void:
	if amount <= 0 or not is_instance_valid(host):
		return
	var attach: Node = host
	var layer := host.get_tree().get_first_node_in_group("ui_layer")
	if layer is Node and (layer as Node).is_inside_tree():
		attach = layer as Node
	var n := FloatingCombatNumber.new()
	n.setup(host, local_center, amount, color)
	attach.add_child(n)
