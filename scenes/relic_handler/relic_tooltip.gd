class_name RelicTooltip
extends Control

const MAX_TEXT_WIDTH := 280.0
const MIN_TEXT_WIDTH := 48.0
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
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
			get_viewport().set_input_as_handled()


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

	relic_tooltip.text = _build_tooltip_bbcode(relic)
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
	_position_panel_once(near_to)


func _build_tooltip_bbcode(relic: Relic) -> String:
	var body := relic.get_tooltip().strip_edges()
	var name := relic.relic_name.strip_edges()
	if name.is_empty():
		return body
	# 名称单独一行；仅转义名字里的方括号，避免破坏 get_tooltip() 里自带的 BBCode
	var safe_name := name.replace("[", "[lb]").replace("]", "[rb]")
	return "[color=#ffdd33][b]%s[/b][/color]\n%s" % [safe_name, body]


func _apply_dynamic_text_size(gen: int) -> void:
	relic_tooltip.autowrap_mode = TextServer.AUTOWRAP_OFF
	relic_tooltip.custom_minimum_size = Vector2(0, 0)
	await get_tree().process_frame
	if gen != _layout_generation:
		return
	var natural_one_line := relic_tooltip.get_content_width() + 8.0
	var box_w := clampf(minf(natural_one_line, MAX_TEXT_WIDTH), MIN_TEXT_WIDTH, MAX_TEXT_WIDTH)
	relic_tooltip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	relic_tooltip.custom_minimum_size = Vector2(box_w, 0)
	await get_tree().process_frame
	if gen != _layout_generation:
		return
	var h := relic_tooltip.get_content_height()
	var used_w := relic_tooltip.get_content_width()
	if used_w > 1.0 and used_w + 4.0 < box_w - 0.5:
		box_w = clampf(used_w + 4.0, MIN_TEXT_WIDTH, box_w)
		relic_tooltip.custom_minimum_size = Vector2(box_w, 0)
		await get_tree().process_frame
		if gen != _layout_generation:
			return
		h = relic_tooltip.get_content_height()
	relic_tooltip.custom_minimum_size = Vector2(box_w, maxf(h, 1.0))


func _position_panel_once(near_to: Control) -> void:
	var vp := get_viewport().get_visible_rect()
	var sz := panel_root.size
	var pos: Vector2
	if is_instance_valid(near_to):
		var gr := near_to.get_global_rect()
		pos = Vector2(gr.end.x + GAP_FROM_RELIC, gr.get_center().y - sz.y * 0.5)
		if pos.x + sz.x > vp.position.x + vp.size.x - VIEWPORT_MARGIN:
			pos.x = gr.position.x - sz.x - GAP_FROM_RELIC
	else:
		pos = vp.get_center() - sz * 0.5
	pos.x = clampf(pos.x, vp.position.x + VIEWPORT_MARGIN, vp.position.x + vp.size.x - sz.x - VIEWPORT_MARGIN)
	pos.y = clampf(pos.y, vp.position.y + VIEWPORT_MARGIN, vp.position.y + vp.size.y - sz.y - VIEWPORT_MARGIN)
	panel_root.global_position = pos
