@tool
class_name CombatantHoverName
extends Label

const FADE_SEC := 0.2
const GAP_BELOW_HEALTH_PX := 4.0
## 高于敌人场景布局 StatusBar（10）及其 buff 图标行。
const DRAW_Z_INDEX := 12
const META_AUTO_LAYOUT := &"auto_layout_from_status_bar"

var _fade_tween: Tween


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	z_as_relative = true
	z_index = DRAW_Z_INDEX
	modulate.a = 0.0
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_TOP
	add_theme_color_override("font_color", Color.WHITE)
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 5)
	add_theme_font_size_override("font_size", 24)


func sync_layout_from_status_bar(status_bar: Control) -> void:
	if status_bar == null:
		return
	var parent_2d := get_parent() as Node2D
	if parent_2d == null:
		return
	var bar_rect := _status_bar_rect_in_parent(status_bar, parent_2d)
	if bar_rect.size.x <= 0.0:
		call_deferred("sync_layout_from_status_bar", status_bar)
		return
	var bottom_y := bar_rect.position.y + bar_rect.size.y
	var health_row := status_bar.get_node_or_null("HealthRow") as Control
	if health_row != null:
		var health_rect := _nested_control_local_rect(health_row, parent_2d)
		if health_rect.size.y > 0.0:
			bottom_y = health_rect.position.y + health_rect.size.y
	var label_h := maxf(get_minimum_size().y, float(get_theme_font_size("font_size")) + 8.0)
	var left_x := bar_rect.position.x
	var top_y := bottom_y + GAP_BELOW_HEALTH_PX
	# Node2D 子 Control 与 StatusBar 一致：position 归零，用 offset 定义外框。
	position = Vector2.ZERO
	offset_left = left_x
	offset_top = top_y
	offset_right = left_x + bar_rect.size.x
	offset_bottom = top_y + label_h
	custom_minimum_size = Vector2.ZERO
	set_meta(META_AUTO_LAYOUT, true)


func set_display_name(text: String) -> void:
	self.text = text.strip_edges()
	var label_h := maxf(get_minimum_size().y, float(get_theme_font_size("font_size")) + 8.0)
	if has_meta(META_AUTO_LAYOUT):
		offset_bottom = offset_top + label_h
	else:
		custom_minimum_size.y = 0.0
		size.y = label_h


func tween_visibility(target_alpha: float) -> void:
	if is_instance_valid(_fade_tween):
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", target_alpha, FADE_SEC)


func hide_immediate() -> void:
	if is_instance_valid(_fade_tween):
		_fade_tween.kill()
		_fade_tween = null
	modulate.a = 0.0


static func _status_bar_rect_in_parent(status_bar: Control, parent_2d: Node2D) -> Rect2:
	if status_bar == null:
		return Rect2()
	var width := 0.0
	if status_bar is StatusBar:
		width = float((status_bar as StatusBar).read_canvas_width())
	if width <= 0.0:
		width = absf(status_bar.offset_right - status_bar.offset_left)
	if width <= 0.0:
		width = status_bar.size.x
	var origin := status_bar.position
	if origin.length_squared() < 0.01:
		origin = Vector2(status_bar.offset_left, status_bar.offset_top)
	var height := absf(status_bar.offset_bottom - status_bar.offset_top)
	if status_bar.is_inside_tree() and parent_2d.is_inside_tree():
		height = maxf(height, status_bar.size.y)
	return Rect2(origin, Vector2(width, maxf(height, 0.0)))


static func _nested_control_local_rect(control: Control, parent_2d: Node2D) -> Rect2:
	if control == null:
		return Rect2()
	if control.is_inside_tree() and parent_2d.is_inside_tree():
		var global_rect := control.get_global_rect()
		return Rect2(parent_2d.to_local(global_rect.position), global_rect.size)
	return _control_local_rect(control, parent_2d)


static func _control_local_rect(control: Control, parent_2d: Node2D) -> Rect2:
	if control == null:
		return Rect2()
	var width := absf(control.offset_right - control.offset_left)
	var height := absf(control.offset_bottom - control.offset_top)
	if width <= 0.0:
		width = control.size.x
	if height <= 0.0:
		height = control.size.y
	var origin := control.position
	if origin.length_squared() < 0.01:
		origin = Vector2(control.offset_left, control.offset_top)
	return Rect2(origin, Vector2(width, height))
