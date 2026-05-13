class_name RelicTooltip
extends Control

const MAX_TEXT_WIDTH := 280.0
const MIN_TEXT_WIDTH := 48.0
## 折行后宽度略小于容器时的收紧阈值（像素），过小会反复改宽导致排版横跳
const WIDTH_SHRINK_SLACK := 10.0
const TEXT_PAD_X := 8.0
const VIEWPORT_MARGIN := 10.0
const GAP_FROM_RELIC := 10.0

@onready var panel_root: PanelContainer = %PanelRoot
@onready var relic_tooltip: RichTextLabel = %RelicTooltip

var _active_relic: Relic
var _active_source: Control
var _layout_generation := 0


func _ready() -> void:
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
		_active_relic = null
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
			# 勿 set_input_as_handled：否则本次点击无法传到下方的商店遗物 / 奖励按钮等，会表现为必须点两次。


func show_tooltip(relic: Relic, near_to: Control = null) -> void:
	if not relic:
		return
	if (
		visible
		and _active_relic == relic
		and _active_source == near_to
		and is_instance_valid(near_to)
	):
		return

	_active_relic = relic
	_active_source = near_to
	_layout_generation += 1
	var gen := _layout_generation

	modulate.a = 0.0
	relic_tooltip.text = _build_tooltip_bbcode(relic)
	show()
	set_process_input(true)

	await _apply_dynamic_text_size(gen)
	if gen != _layout_generation:
		return
	_position_panel_once(near_to)
	if gen != _layout_generation:
		return
	await get_tree().process_frame
	if gen != _layout_generation:
		return
	modulate.a = 1.0


func _build_tooltip_bbcode(relic: Relic) -> String:
	var body := relic.get_tooltip().strip_edges()
	var name := relic.relic_name.strip_edges()
	if name.is_empty():
		return body
	# 名称单独一行；仅转义名字里的方括号，避免破坏 get_tooltip() 里自带的 BBCode
	var safe_name := name.replace("[", "[lb]").replace("]", "[rb]")
	return "[color=#ffdd33][b]%s[/b][/color]\n%s" % [safe_name, body]


func _apply_dynamic_text_size(gen: int) -> void:
	var rtl := relic_tooltip
	# 与 fit_content 二选一：脚本统一算最小宽高，避免与 Panel 布局每帧打架造成横跳
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


func _position_panel_once(near_to: Control) -> void:
	panel_root.reset_size()
	var vp := get_viewport().get_visible_rect()
	var sz := panel_root.size
	if sz.x < 2.0 or sz.y < 2.0:
		sz = panel_root.get_combined_minimum_size()
	var pos: Vector2
	if is_instance_valid(near_to):
		var gr := near_to.get_global_rect()
		# 默认贴在遗物右侧；仅当整体超出视口右缘时才改到遗物左侧
		pos = Vector2(gr.end.x + GAP_FROM_RELIC, gr.get_center().y - sz.y * 0.5)
		if pos.x + sz.x > vp.position.x + vp.size.x - VIEWPORT_MARGIN:
			pos.x = gr.position.x - sz.x - GAP_FROM_RELIC
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
