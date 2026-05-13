class_name CardKeywordTooltip
extends Control

const VIEWPORT_MARGIN := 10.0
const GAP_FROM_SOURCE := 12.0
const BLOCK_SEP := 8.0

const BB_ETHEREAL := "[color=#ffdd33][b]虚无[/b][/color]\n如果回合结束后这张牌在你的手牌中，则将这张牌消耗。"
const BB_EXHAUST := "[color=#ffdd33][b]消耗[/b][/color]\n消耗的牌会进入你的消耗牌堆。"
const BB_VULNERABLE := "[color=#ffdd33][b]易伤[/b][/color]\n受到的伤害增加50%。"
const BB_STRENGTH := "[color=#ffdd33][b]力量[/b][/color]\n增加造成的伤害。"

## RichTextLabel 字号用 `*_font_size`；`normal_font`/`bold_font` 是 Font 资源名，对它们 set font_size 无效。
const KEYWORD_TOOLTIP_FONT_SIZE := 16
## 单行过宽时才按此宽度换行；短于该宽度则面板随文本收窄。
const MAX_TOOLTIP_LINE_WIDTH := 380.0

@onready var panel_root: PanelContainer = %PanelRoot
@onready var vbox: VBoxContainer = %VBox

var _layout_generation := 0


func _ready() -> void:
	hide()
	set_process_input(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		set_process_input(false)
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


func show_keyword_blocks(ids: PackedStringArray, near_to: Control) -> void:
	if ids.is_empty():
		return
	_layout_generation += 1
	var gen := _layout_generation
	hide()
	set_process_input(false)
	for c in vbox.get_children():
		c.queue_free()
	for id in ids:
		var rtl := RichTextLabel.new()
		rtl.bbcode_enabled = true
		rtl.fit_content = true
		rtl.scroll_active = false
		rtl.autowrap_mode = TextServer.AUTOWRAP_OFF
		rtl.custom_minimum_size = Vector2.ZERO
		rtl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		rtl.add_theme_font_size_override("normal_font_size", KEYWORD_TOOLTIP_FONT_SIZE)
		rtl.add_theme_font_size_override("bold_font_size", KEYWORD_TOOLTIP_FONT_SIZE)
		rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		match String(id):
			"ethereal":
				rtl.text = BB_ETHEREAL
			"exhaust":
				rtl.text = BB_EXHAUST
			"vulnerable":
				rtl.text = BB_VULNERABLE
			"strength":
				rtl.text = BB_STRENGTH
			_:
				continue
		vbox.add_child(rtl)

	if vbox.get_child_count() == 0:
		return

	vbox.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	if get_parent():
		get_parent().move_child(self, -1)

	await get_tree().process_frame
	if gen != _layout_generation:
		return
	# RichTextLabel fit_content 再留一帧，避免 combined size 未更新导致定位不准
	await get_tree().process_frame
	if gen != _layout_generation:
		return

	_shrink_tooltip_blocks_to_content()
	await get_tree().process_frame
	if gen != _layout_generation:
		return

	_position_panel(near_to)
	set_process_input(true)
	show()


func _shrink_tooltip_blocks_to_content() -> void:
	var vp_w := get_viewport().get_visible_rect().size.x
	var cap_w := minf(MAX_TOOLTIP_LINE_WIDTH, maxf(80.0, vp_w - VIEWPORT_MARGIN * 2.0 - 24.0))
	var need_rewrap := false
	for c: Node in vbox.get_children():
		if not c is RichTextLabel:
			continue
		var r := c as RichTextLabel
		var natural_w := r.get_content_width()
		if natural_w > cap_w:
			r.custom_minimum_size = Vector2(cap_w, 0)
			r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			need_rewrap = true
		else:
			r.custom_minimum_size = Vector2.ZERO
			r.autowrap_mode = TextServer.AUTOWRAP_OFF
	if need_rewrap:
		panel_root.reset_size()


func _position_panel(near_to: Control) -> void:
	panel_root.reset_size()
	var vp := get_viewport().get_visible_rect()
	var sz := panel_root.size
	if sz.x < 2.0 or sz.y < 2.0:
		sz = panel_root.get_combined_minimum_size()
	var pos: Vector2
	if is_instance_valid(near_to):
		var gr := near_to.get_global_rect()
		var right_x := gr.end.x + GAP_FROM_SOURCE
		var max_x_allow := vp.position.x + vp.size.x - sz.x - VIEWPORT_MARGIN
		if right_x <= max_x_allow:
			pos = Vector2(right_x, gr.position.y)
		else:
			pos = Vector2(gr.position.x - GAP_FROM_SOURCE - sz.x, gr.position.y)
	else:
		pos = vp.get_center() - sz * 0.5
	var max_x := vp.position.x + vp.size.x - sz.x - VIEWPORT_MARGIN
	var max_y := vp.position.y + vp.size.y - sz.y - VIEWPORT_MARGIN
	pos.x = clampf(pos.x, vp.position.x + VIEWPORT_MARGIN, maxf(vp.position.x + VIEWPORT_MARGIN, max_x))
	pos.y = clampf(pos.y, vp.position.y + VIEWPORT_MARGIN, maxf(vp.position.y + VIEWPORT_MARGIN, max_y))
	panel_root.global_position = pos


func hide_tooltip() -> void:
	hide()
