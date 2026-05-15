class_name StatusHoverTooltip
extends Control

const MAX_TEXT_WIDTH := 280.0
const MIN_TEXT_WIDTH := 48.0
## 折行后宽度略小于容器时的收紧阈值（像素），过小会反复改宽导致排版横跳
const WIDTH_SHRINK_SLACK := 10.0
const TEXT_PAD_X := 8.0
const VIEWPORT_MARGIN := 10.0
const GAP_FROM_ICON := 10.0

@onready var panel_root: PanelContainer = %PanelRoot
@onready var body: RichTextLabel = %StatusTooltipBody

var _active_status: Status
var _active_source: Control
var _open_to_right := true
var _layout_generation := 0
var _is_custom_tooltip := false
var _active_custom_bbcode: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(false)
	hide()
	for c in panel_root.get_children():
		if c is MarginContainer:
			(c as MarginContainer).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			(c as MarginContainer).size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			break


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		modulate.a = 1.0
		set_process_input(false)
		_active_status = null
		_active_source = null
		_is_custom_tooltip = false
		_active_custom_bbcode = ""
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
			# 勿吞掉点击，避免需点两次才能点到下层控件。

func show_custom_bbcode(bbcode: String, near_to: Control = null, open_to_right: bool = true) -> void:
	var trimmed := bbcode.strip_edges()
	if trimmed.is_empty():
		return
	var near_valid: Control = null
	if is_instance_valid(near_to):
		near_valid = near_to
	if (
		visible
		and _is_custom_tooltip
		and _active_custom_bbcode == trimmed
		and _active_source == near_valid
		and _open_to_right == open_to_right
	):
		return

	_is_custom_tooltip = true
	_active_custom_bbcode = trimmed
	_active_status = null
	_active_source = near_valid
	_open_to_right = open_to_right
	_layout_generation += 1
	var gen_c := _layout_generation

	modulate.a = 0.0
	body.text = trimmed
	show()
	set_process_input(true)

	await _apply_dynamic_text_size(gen_c)
	if gen_c != _layout_generation:
		return
	var anchor: Control = null
	if is_instance_valid(near_to):
		anchor = near_to
	_position_panel_once(anchor, open_to_right)
	if gen_c != _layout_generation:
		return
	await get_tree().process_frame
	if gen_c != _layout_generation:
		return
	modulate.a = 1.0


func show_tooltip(status: Status, near_to: Control = null, open_to_right: bool = true) -> void:
	if not status:
		return
	var near_valid: Control = null
	if is_instance_valid(near_to):
		near_valid = near_to
	if (
		visible
		and not _is_custom_tooltip
		and _active_status != null
		and _active_status.id == status.id
		and _active_source == near_valid
		and _open_to_right == open_to_right
	):
		return

	_is_custom_tooltip = false
	_active_custom_bbcode = ""
	_active_status = status
	_active_source = near_valid
	_open_to_right = open_to_right
	_layout_generation += 1
	var gen := _layout_generation

	modulate.a = 0.0
	body.text = _build_bbcode(status)
	show()
	set_process_input(true)

	await _apply_dynamic_text_size(gen)
	if gen != _layout_generation:
		return
	var anchor2: Control = null
	if is_instance_valid(near_to):
		anchor2 = near_to
	_position_panel_once(anchor2, open_to_right)
	if gen != _layout_generation:
		return
	await get_tree().process_frame
	if gen != _layout_generation:
		return
	modulate.a = 1.0


func _build_bbcode(s: Status) -> String:
	var title := s.get_display_name()
	var safe_title := title.replace("[", "[lb]").replace("]", "[rb]")
	var tip := s.get_tooltip().strip_edges()
	return "[color=#ffdd33][b]%s[/b][/color]\n%s" % [safe_title, tip]


func _apply_dynamic_text_size(gen: int) -> void:
	var rtl := body
	rtl.fit_content = false
	rtl.scroll_active = false
	rtl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rtl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	rtl.autowrap_mode = TextServer.AUTOWRAP_OFF
	rtl.custom_minimum_size = Vector2.ZERO
	await get_tree().process_frame
	if gen != _layout_generation:
		return
	var intrinsic := rtl.get_content_width()
	if not is_finite(intrinsic) or intrinsic < 1.0:
		intrinsic = MIN_TEXT_WIDTH
	var box_w := clampf(ceilf(intrinsic) + TEXT_PAD_X, MIN_TEXT_WIDTH, MAX_TEXT_WIDTH)
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.custom_minimum_size = Vector2(box_w, 0.0)
	await get_tree().process_frame
	if gen != _layout_generation:
		return
	var used := ceilf(rtl.get_content_width())
	if used > 1.0 and box_w - used >= WIDTH_SHRINK_SLACK:
		box_w = clampf(used + TEXT_PAD_X * 0.5, MIN_TEXT_WIDTH, box_w)
		rtl.custom_minimum_size = Vector2(box_w, 0.0)
		await get_tree().process_frame
		if gen != _layout_generation:
			return
	var h := maxf(1.0, ceilf(rtl.get_content_height()))
	rtl.custom_minimum_size = Vector2(box_w, h)
	panel_root.reset_size()
	await get_tree().process_frame
	if gen != _layout_generation:
		return


func _position_panel_once(near_to: Control = null, open_to_right: bool = true) -> void:
	panel_root.reset_size()
	var vp := get_viewport().get_visible_rect()
	var sz := panel_root.size
	if sz.x < 2.0 or sz.y < 2.0:
		sz = panel_root.get_combined_minimum_size()
	var pos: Vector2
	if is_instance_valid(near_to):
		var gr := near_to.get_global_rect()
		var center_y := gr.get_center().y - sz.y * 0.5
		# 玩家 StatusBar：open_to_right=true，说明始终在图标右侧；敌人 false 始终在左侧
		if open_to_right:
			pos = Vector2(gr.end.x + GAP_FROM_ICON, center_y)
		else:
			pos = Vector2(gr.position.x - sz.x - GAP_FROM_ICON, center_y)
	else:
		pos = vp.get_center() - sz * 0.5
	pos = _clamp_tooltip_to_viewport(pos, sz, vp)
	panel_root.global_position = pos


func _clamp_tooltip_to_viewport(pos: Vector2, sz: Vector2, vp: Rect2) -> Vector2:
	var min_x := vp.position.x + VIEWPORT_MARGIN
	var max_x := vp.position.x + vp.size.x - sz.x - VIEWPORT_MARGIN
	if max_x >= min_x:
		pos.x = clampf(pos.x, min_x, max_x)
	else:
		pos.x = vp.get_center().x - sz.x * 0.5
	var min_y := vp.position.y + VIEWPORT_MARGIN
	var max_y := vp.position.y + vp.size.y - sz.y - VIEWPORT_MARGIN
	if max_y >= min_y:
		pos.y = clampf(pos.y, min_y, max_y)
	else:
		pos.y = vp.get_center().y - sz.y * 0.5
	return pos
