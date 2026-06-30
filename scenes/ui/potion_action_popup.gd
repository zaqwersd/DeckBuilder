class_name PotionActionPopup
extends CanvasLayer

signal closed

const DISCARD_RED := Color(0.92, 0.22, 0.22)
const GAP_BELOW_SLOT := 4.0
const MAX_LAYOUT_FRAMES := 16
const STABLE_FRAMES_REQUIRED := 2

@onready var _dim: ColorRect = %Dim
@onready var _panel: PanelContainer = %Panel
@onready var _use_button: Button = %UseButton
@onready var _discard_button: Button = %DiscardButton

var slot_index: int = -1

var _handler: PotionHandler
var _anchor: Control
var _pending_potion: Potion
var _positioning_token := 0


func _ready() -> void:
	_panel.top_level = true
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.visible = false
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.gui_input.connect(_on_dim_gui_input)
	_use_button.pressed.connect(_on_use_pressed)
	_discard_button.pressed.connect(_on_discard_pressed)
	_discard_button.add_theme_color_override("font_color", DISCARD_RED)
	_discard_button.add_theme_color_override("font_hover_color", DISCARD_RED.lightened(0.15))
	_discard_button.add_theme_color_override("font_pressed_color", DISCARD_RED.darkened(0.1))
	_discard_button.add_theme_color_override("font_disabled_color", DISCARD_RED.darkened(0.35))
	if _pending_potion != null:
		_finish_setup()


func setup(handler: PotionHandler, index: int, anchor: Control, potion: Potion) -> void:
	slot_index = index
	_handler = handler
	_anchor = anchor
	_pending_potion = potion
	if is_node_ready():
		_finish_setup()


func _finish_setup() -> void:
	if _handler != null:
		_use_button.disabled = not _handler.can_use_potion(_pending_potion)
	if _pending_potion != null:
		_panel.tooltip_text = _pending_potion.tooltip
	_hide_panel_for_layout()
	_show_panel_when_positioned()


func reposition_to_anchor() -> void:
	if not is_node_ready():
		return
	_hide_panel_for_layout()
	_show_panel_when_positioned()


func _hide_panel_for_layout() -> void:
	_panel.visible = false
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _show_panel_when_positioned() -> void:
	_positioning_token += 1
	var token := _positioning_token
	_run_positioning_loop(token)


func _run_positioning_loop(token: int) -> void:
	await _position_panel_when_stable(token)
	if not is_inside_tree() or token != _positioning_token:
		return
	_panel.visible = true
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP


func _position_panel_when_stable(token: int) -> void:
	var last_pos := Vector2.INF
	var stable_streak := 0
	for _i in range(MAX_LAYOUT_FRAMES):
		if token != _positioning_token or not is_inside_tree():
			return
		await get_tree().process_frame
		if token != _positioning_token or not is_instance_valid(_anchor):
			return
		if not _apply_panel_position():
			stable_streak = 0
			last_pos = Vector2.INF
			continue
		var pos := _panel.global_position
		if pos.is_equal_approx(last_pos):
			stable_streak += 1
			if stable_streak >= STABLE_FRAMES_REQUIRED:
				return
		else:
			stable_streak = 0
			last_pos = pos
	if token == _positioning_token and is_instance_valid(_anchor):
		_apply_panel_position()


func _apply_panel_position() -> bool:
	if not is_instance_valid(_anchor) or not is_instance_valid(_panel):
		return false
	var slot_rect := _anchor.get_global_rect()
	if slot_rect.size.x <= 0.0 or slot_rect.size.y <= 0.0:
		return false
	_panel.reset_size()
	var panel_size := _panel.get_combined_minimum_size()
	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		return false
	_panel.size = panel_size
	_panel.global_position = Vector2(
		slot_rect.position.x + (slot_rect.size.x - panel_size.x) * 0.5,
		slot_rect.end.y + GAP_BELOW_SLOT
	)
	return true


func _on_dim_gui_input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	if not _is_left_press(event):
		return
	if _panel.get_global_rect().has_point(event.global_position):
		return
	_close()


func _is_left_press(event: InputEvent) -> bool:
	return (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	)


func _on_use_pressed() -> void:
	if _handler == null or slot_index < 0:
		_close()
		return
	Events.potion_tooltip_hover_hide.emit()
	_set_targeting_mode(true)
	var ok: bool = await _handler.use_at(slot_index, _anchor)
	_set_targeting_mode(false)
	if not is_inside_tree():
		return
	if ok:
		_close()
	else:
		_use_button.disabled = not _handler.can_use_potion(_pending_potion)
		reposition_to_anchor()


func _set_targeting_mode(active: bool) -> void:
	if active:
		_positioning_token += 1
		_hide_panel_for_layout()
	else:
		pass


func _on_discard_pressed() -> void:
	Events.potion_tooltip_hover_hide.emit()
	var handler := _handler
	var idx := slot_index
	_handler = null
	slot_index = -1
	_close()
	if handler != null and idx >= 0:
		handler.remove_at(idx)


func _close() -> void:
	if not is_inside_tree():
		return
	_positioning_token += 1
	closed.emit()
	queue_free()
