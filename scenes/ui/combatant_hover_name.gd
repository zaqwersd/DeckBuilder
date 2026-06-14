class_name CombatantHoverName
extends Label

const FADE_SEC := 0.2

var _fade_tween: Tween


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	z_index = 8
	modulate.a = 0.0
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_color_override("font_color", Color.WHITE)
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 5)
	add_theme_font_size_override("font_size", 18)


func sync_layout_from_status_bar(status_bar: Control) -> void:
	if status_bar == null:
		return
	position = status_bar.position
	size = status_bar.size


func set_display_name(text: String) -> void:
	self.text = text.strip_edges()


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
