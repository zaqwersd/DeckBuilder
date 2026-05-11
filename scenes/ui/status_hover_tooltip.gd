class_name StatusHoverTooltip
extends Control

const MAX_TEXT_WIDTH := 280.0
const MIN_TEXT_WIDTH := 48.0
const VIEWPORT_MARGIN := 10.0
const GAP_FROM_ICON := 10.0

@onready var panel_root: PanelContainer = %PanelRoot
@onready var body: RichTextLabel = %StatusTooltipBody

var _active_status: Status
var _active_source: Control
var _open_to_right := true
var _layout_generation := 0


func _ready() -> void:
	set_process_input(false)
	hide()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		set_process_input(false)
		_active_status = null
		_active_source = null
		_layout_generation += 1


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if is_instance_valid(panel_root) and not panel_root.get_global_rect().has_point(mb.global_position):
			hide()
			get_viewport().set_input_as_handled()


func show_tooltip(status: Status, near_to: Control = null, open_to_right: bool = true) -> void:
	if not status:
		return
	if (
		visible
		and _active_status == status
		and _active_source == near_to
		and _open_to_right == open_to_right
		and is_instance_valid(near_to)
	):
		return

	_active_status = status
	_active_source = near_to
	_open_to_right = open_to_right
	_layout_generation += 1
	var gen := _layout_generation

	body.text = _build_bbcode(status)
	show()
	set_process_input(true)

	await get_tree().process_frame
	if gen != _layout_generation:
		return
	await _apply_dynamic_text_size(gen)
	if gen != _layout_generation:
		return
	await get_tree().process_frame
	if gen != _layout_generation:
		return
	_position_panel_once(near_to, open_to_right)


func _build_bbcode(s: Status) -> String:
	var title := s.get_display_name()
	var safe_title := title.replace("[", "[lb]").replace("]", "[rb]")
	var tip := s.get_tooltip().strip_edges()
	return "[color=#ffdd33][b]%s[/b][/color]\n%s" % [safe_title, tip]


func _apply_dynamic_text_size(gen: int) -> void:
	body.autowrap_mode = TextServer.AUTOWRAP_OFF
	body.custom_minimum_size = Vector2(0, 0)
	await get_tree().process_frame
	if gen != _layout_generation:
		return
	var natural_one_line := body.get_content_width() + 8.0
	var box_w := clampf(minf(natural_one_line, MAX_TEXT_WIDTH), MIN_TEXT_WIDTH, MAX_TEXT_WIDTH)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(box_w, 0)
	await get_tree().process_frame
	if gen != _layout_generation:
		return
	var h := body.get_content_height()
	var used_w := body.get_content_width()
	if used_w > 1.0 and used_w + 4.0 < box_w - 0.5:
		box_w = clampf(used_w + 4.0, MIN_TEXT_WIDTH, box_w)
		body.custom_minimum_size = Vector2(box_w, 0)
		await get_tree().process_frame
		if gen != _layout_generation:
			return
		h = body.get_content_height()
	body.custom_minimum_size = Vector2(box_w, maxf(h, 1.0))


func _position_panel_once(near_to: Control, open_to_right: bool) -> void:
	var vp := get_viewport().get_visible_rect()
	var sz := panel_root.size
	var pos: Vector2
	if is_instance_valid(near_to):
		var gr := near_to.get_global_rect()
		var center_y := gr.get_center().y - sz.y * 0.5
		if open_to_right:
			pos = Vector2(gr.end.x + GAP_FROM_ICON, center_y)
		else:
			pos = Vector2(gr.position.x - sz.x - GAP_FROM_ICON, center_y)
	else:
		pos = vp.get_center() - sz * 0.5
	pos.x = clampf(pos.x, vp.position.x + VIEWPORT_MARGIN, vp.position.x + vp.size.x - sz.x - VIEWPORT_MARGIN)
	pos.y = clampf(pos.y, vp.position.y + VIEWPORT_MARGIN, vp.position.y + vp.size.y - sz.y - VIEWPORT_MARGIN)
	panel_root.global_position = pos
