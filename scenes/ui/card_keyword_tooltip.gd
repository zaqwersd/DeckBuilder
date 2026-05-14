class_name CardKeywordTooltip
extends Control

const VIEWPORT_MARGIN := 10.0
const GAP_FROM_SOURCE := 12.0

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
	if is_instance_valid(vbox):
		## 多块上下排布时整体靠左（VBox 横轴对齐）
		vbox.alignment = BoxContainer.ALIGNMENT_BEGIN


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
	await _render_keyword_blocks(ids, near_to)


func hide_tooltip() -> void:
	hide()


## 按正文内 `[url=kw:…]` 做 DFS：先展示当前词条，再立刻接上链接指向的词条（无需悬停）。
func _expand_tooltip_ids_depth_first(seed_ids: PackedStringArray) -> PackedStringArray:
	var out: Array[String] = []
	var seen: Dictionary = {}
	for i in range(seed_ids.size()):
		_dfs_append_tooltip_id(String(seed_ids[i]), seen, out)
	return PackedStringArray(out)


func _dfs_append_tooltip_id(id: String, seen: Dictionary, out: Array[String]) -> void:
	if id.is_empty() or seen.has(id):
		return
	if CardKeywordBbcode.get_keyword_tooltip_body_bbcode(id, false).is_empty():
		return
	seen[id] = true
	out.append(id)
	var body := CardKeywordBbcode.get_keyword_tooltip_body_bbcode(id, true)
	var linked := CardKeywordBbcode.collect_kw_ids_in_order_from_bbcode(body)
	for j in range(linked.size()):
		_dfs_append_tooltip_id(String(linked[j]), seen, out)


func _render_keyword_blocks(seed_ids: PackedStringArray, near_to: Control) -> void:
	_layout_generation += 1
	var gen := _layout_generation
	hide()
	set_process_input(false)
	for c in vbox.get_children():
		c.queue_free()

	var expanded := _expand_tooltip_ids_depth_first(seed_ids)
	if expanded.is_empty():
		return

	var seed_set: Dictionary = {}
	for i in range(seed_ids.size()):
		seed_set[String(seed_ids[i])] = true

	for bi in range(expanded.size()):
		var id := String(expanded[bi])
		if bi > 0:
			var sep := HSeparator.new()
			sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sep.custom_minimum_size = Vector2(0, 1)
			vbox.add_child(sep)
		var embed_links: bool = seed_set.has(id)
		var body := CardKeywordBbcode.get_keyword_tooltip_body_bbcode(id, embed_links)
		if body.is_empty():
			continue
		var rtl := RichTextLabel.new()
		rtl.bbcode_enabled = true
		rtl.fit_content = true
		rtl.scroll_active = false
		rtl.autowrap_mode = TextServer.AUTOWRAP_OFF
		rtl.custom_minimum_size = Vector2.ZERO
		rtl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		rtl.add_theme_font_size_override("normal_font_size", KEYWORD_TOOLTIP_FONT_SIZE)
		rtl.add_theme_font_size_override("bold_font_size", KEYWORD_TOOLTIP_FONT_SIZE)
		## 链接词条已由下方块展示，无需再悬停点链
		rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtl.text = CardKeywordBbcode.wrap_ascii_digit_runs_bold(CardKeywordBbcode.inject_keywords(body))
		vbox.add_child(rtl)

	if vbox.get_child_count() == 0:
		return

	vbox.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if get_parent():
		get_parent().move_child(self, -1)

	await get_tree().process_frame
	if gen != _layout_generation:
		return
	await get_tree().process_frame
	if gen != _layout_generation:
		return

	_shrink_tooltip_blocks_to_content()
	await get_tree().process_frame
	if gen != _layout_generation:
		return

	# 检查 near_to 是否仍然有效（可能在等待期间被释放）
	if not is_instance_valid(near_to):
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
