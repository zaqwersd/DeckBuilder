class_name GameTooltip
extends Control

enum Placement { CARD_RIGHT, RELIC_FLIP, ICON_RIGHT, ICON_LEFT, INTENT_LEFT }

const VIEWPORT_MARGIN := 10.0
const GAP_FROM_SOURCE := 12.0
const GAP_FROM_ICON := 10.0
## 意图悬停 tooltip 在 ICON_LEFT 基础上再向右平移（像素）
const INTENT_TOOLTIP_OFFSET_X := 64.0
const TOOLTIP_FONT_SIZE := 16
## 正文最大宽度（像素）；超出则自动换行
const MAX_TEXT_WIDTH := 192.0
const MIN_TEXT_WIDTH := 24.0
## 排版测量时把面板放到屏外，避免未定位时闪一下
const OFFSCREEN_LAYOUT_POS := Vector2(-100000.0, -100000.0)
## await 后勿再传递 Control 引用（可能已释放）；用 instance_id 解析锚点
const INVALID_ANCHOR_ID := -1

@onready var panel_root: PanelContainer = %PanelRoot
@onready var vbox: VBoxContainer = %VBox

var _layout_generation := 0
var _active_relic: Relic
var _active_source: Control
var _titled_meta_rtl: RichTextLabel = null
var _pending_keyword_restore: Dictionary = {}
var _hover_anchor_id: int = INVALID_ANCHOR_ID
var _hover_placement: Placement = Placement.ICON_RIGHT
var _hover_poll_active: bool = false
var _follow_screen_rect_active: bool = false
var _follow_screen_rect: Rect2 = Rect2()
var _follow_placement: Placement = Placement.ICON_RIGHT
var _active_potion: Potion = null
var _hide_request_serial: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = true
	set_process(false)
	if is_instance_valid(panel_root):
		panel_root.hide()
	if is_instance_valid(vbox):
		vbox.alignment = BoxContainer.ALIGNMENT_BEGIN


func _process(_delta: float) -> void:
	if _follow_screen_rect_active:
		if is_instance_valid(panel_root) and panel_root.visible:
			_position_panel_at_rect(_follow_screen_rect, _follow_placement)
		else:
			_follow_screen_rect_active = false
			_sync_tooltip_process()
	if not _hover_poll_active:
		return
	if not is_instance_valid(panel_root) or not panel_root.visible:
		_stop_hover_poll()
		return
	var anchor := _resolve_anchor(_hover_anchor_id)
	if anchor == null:
		hide_tooltip_immediate()
		return
	var viewport := get_viewport()
	if viewport == null:
		hide_tooltip_immediate()
		return
	var screen_pos := CombatPointer.screen_mouse(viewport)
	if not _control_has_screen_point_for_tooltip(anchor, screen_pos):
		hide_tooltip_immediate()
		return
	if _hover_anchor_obscured_for_poll(anchor):
		hide_tooltip_immediate()
		return


func _stop_hover_poll() -> void:
	_hover_poll_active = false
	_hover_anchor_id = INVALID_ANCHOR_ID
	_sync_tooltip_process()


func _sync_tooltip_process() -> void:
	set_process(_follow_screen_rect_active or _hover_poll_active)


func _cancel_screen_rect_follow() -> void:
	_follow_screen_rect_active = false
	_sync_tooltip_process()


## TopBar（遗物/药水等）与牌库同处 layer 3，打开牌库时不应被 pointer_exclusive 误判为遮挡。
func _is_run_top_bar_hover_anchor(anchor: Control) -> bool:
	if anchor == null or not is_instance_valid(anchor) or not anchor.is_inside_tree():
		return false
	var run := anchor.get_tree().get_first_node_in_group("run")
	if run == null:
		return false
	var top_bar := run.get_node_or_null("TopBar")
	return top_bar != null and top_bar.is_ancestor_of(anchor)


func _control_has_screen_point_for_tooltip(anchor: Control, screen_pos: Vector2, padding: float = 0.0) -> bool:
	if not is_instance_valid(anchor) or not anchor.is_inside_tree():
		return false
	if _is_run_top_bar_hover_anchor(anchor):
		var rect := anchor.get_global_rect()
		if padding > 0.0:
			rect = rect.grow(padding)
		return rect.has_point(screen_pos)
	return CombatPointer.control_has_screen_point(anchor, screen_pos, padding)


func _pointer_over_run_top_bar_relic() -> bool:
	var viewport := get_viewport()
	if viewport == null:
		return false
	var run := get_tree().get_first_node_in_group("run")
	if run == null:
		return false
	var handler := run.get_node_or_null("%RelicHandler") as RelicHandler
	if handler == null:
		return false
	var relics := handler.get_node_or_null("%Relics") as HBoxContainer
	if relics == null:
		return false
	var screen_pos := CombatPointer.screen_mouse(viewport)
	for child in relics.get_children():
		if child is RelicUI:
			if _control_has_screen_point_for_tooltip(child as Control, screen_pos, 4.0):
				return true
	return false


func _hover_anchor_obscured_for_poll(anchor: Control) -> bool:
	if not _hover_poll_respects_obscured():
		return false
	if _is_run_top_bar_hover_anchor(anchor):
		return false
	return Events.is_pointer_ui_obscured_for(anchor)


func _ensure_full_opacity() -> void:
	modulate.a = 1.0


## 悬停离开信号：延迟一帧，若指针已移到新锚点（如相邻商店药水）则不关闭。
func hide_tooltip() -> void:
	_hide_request_serial += 1
	var serial := _hide_request_serial
	call_deferred("_deferred_hide_tooltip", serial)


func hide_tooltip_immediate() -> void:
	_hide_request_serial += 1
	_apply_hide_tooltip()


func _deferred_hide_tooltip(serial: int) -> void:
	if serial != _hide_request_serial:
		return
	if _pointer_still_over_hover_anchor():
		return
	if _pointer_over_visible_shop_item():
		return
	if _pointer_over_run_top_bar_relic():
		return
	_apply_hide_tooltip()


func _pointer_over_visible_shop_item() -> bool:
	var viewport := get_viewport()
	if viewport == null:
		return false
	var shop := _find_visible_shop(viewport)
	if shop == null:
		return false
	var screen_pos := CombatPointer.screen_mouse(viewport)
	var relic := shop._shop_relic_under_pointer()
	if relic != null:
		return true
	var potion := shop._shop_potion_under_pointer()
	return potion != null


func _find_visible_shop(viewport: Viewport) -> Shop:
	return _find_shop_recursive(viewport.get_tree().root)


func _find_shop_recursive(node: Node) -> Shop:
	if node is Shop and (node as Shop).visible:
		return node as Shop
	for child in node.get_children():
		var found := _find_shop_recursive(child)
		if found != null:
			return found
	return null


func _is_shop_item_tooltip_anchor(near_to: Control) -> bool:
	var node: Node = near_to
	while node != null:
		if node is ShopRelic or node is ShopPotion:
			return true
		node = node.get_parent()
	return false


func _pointer_still_over_hover_anchor() -> bool:
	var anchor := _resolve_anchor(_hover_anchor_id)
	if anchor == null:
		return false
	var viewport := get_viewport()
	if viewport == null:
		return false
	var screen_pos := CombatPointer.screen_mouse(viewport)
	if not _control_has_screen_point_for_tooltip(anchor, screen_pos):
		return false
	if _hover_anchor_obscured_for_poll(anchor):
		return false
	return true


func _hover_poll_respects_obscured() -> bool:
	return Events.get_pointer_exclusive_leaf() != null


func _apply_hide_tooltip() -> void:
	_layout_generation += 1
	_cancel_screen_rect_follow()
	_stop_hover_poll()
	_clear_titled_meta()
	_active_relic = null
	_active_source = null
	_active_potion = null
	Events.card_keyword_tooltip_visible = false
	Events.card_keyword_tooltip_render_pending = false
	_clear_vbox()
	_reset_panel_visual_state()
	if is_instance_valid(panel_root):
		panel_root.hide()


func show_keyword_blocks(ids: PackedStringArray, near_to: Control) -> void:
	if CardKeywordBbcode.is_combat_tooltip_anchor(near_to):
		ids = CardKeywordBbcode.without_color_tooltip_ids(ids)
	if ids.is_empty():
		return
	if Events.card_keyword_tooltip_render_pending:
		Events.card_keyword_tooltip_render_pending = false
	Events.card_keyword_tooltip_render_pending = true
	await _render_keyword_blocks(ids, _capture_anchor_id(near_to), Placement.CARD_RIGHT)
	Events.card_keyword_tooltip_render_pending = false


## 药水 Events 兼容
func show_potion_tooltip(potion: Potion, near_to: Control = null) -> void:
	if potion == null:
		return
	if (
		is_instance_valid(panel_root)
		and panel_root.visible
		and _active_potion != null
		and potion != null
		and _active_potion.id == potion.id
		and _active_source == near_to
		and is_instance_valid(near_to)
	):
		return
	_active_relic = null
	_active_potion = potion
	_active_source = near_to
	var body := CardKeywordBbcode.inject_keywords(potion.tooltip.strip_edges())
	var hover_poll := near_to == null or not _is_shop_item_tooltip_anchor(near_to)
	await show_titled(potion.potion_name, body, near_to, Placement.ICON_RIGHT, true, hover_poll)


## 遗物 Events 兼容
func show_tooltip(relic: Relic, near_to: Control = null) -> void:
	if relic == null:
		return
	if (
		is_instance_valid(panel_root)
		and panel_root.visible
		and _active_relic == relic
		and _active_source == near_to
		and is_instance_valid(near_to)
	):
		return
	_active_relic = relic
	_active_source = near_to
	var body := CardKeywordBbcode.inject_keywords(relic.get_tooltip().strip_edges())
	var hover_poll := near_to == null or not _is_shop_item_tooltip_anchor(near_to)
	await show_titled(relic.relic_name, body, near_to, Placement.RELIC_FLIP, true, hover_poll)


## 状态 Events 兼容
func show_status_tooltip(status: Status, near_to: Control = null, open_to_right: bool = true) -> void:
	if status == null:
		return
	_active_relic = null
	var placement := Placement.ICON_RIGHT if open_to_right else Placement.ICON_LEFT
	var body := CardKeywordBbcode.inject_keywords(status.get_tooltip().strip_edges())
	await show_titled(status.get_display_name(), body, near_to, placement, false, false)


## 意图 Events 兼容；bbcode 已含标题（Intent.build_intent_hover_bbcode）
func show_custom_bbcode(bbcode: String, near_to: Control = null, open_to_right: bool = true) -> void:
	var trimmed := bbcode.strip_edges()
	if trimmed.is_empty():
		return
	_active_relic = null
	await show_titled_bbcode(trimmed, near_to, Placement.INTENT_LEFT, false)


func show_titled(
	title: String,
	body_bbcode: String,
	near_to: Control,
	placement: Placement,
	enable_keyword_meta: bool = false,
	enable_hover_poll: bool = true
) -> void:
	var full := TooltipBbcode.titled(title, body_bbcode)
	await show_titled_bbcode(full, near_to, placement, enable_keyword_meta, enable_hover_poll)


func show_titled_bbcode(
	full_bbcode: String,
	near_to: Control,
	placement: Placement,
	enable_keyword_meta: bool = false,
	enable_hover_poll: bool = true
) -> void:
	var trimmed := full_bbcode.strip_edges()
	if trimmed.is_empty():
		return
	_hide_request_serial += 1
	_layout_generation += 1
	var gen := _layout_generation
	var anchor_id := _capture_anchor_id(near_to)
	_hover_anchor_id = anchor_id
	_cancel_screen_rect_follow()
	_stop_hover_poll()
	_conceal_panel()
	_clear_vbox()
	_clear_titled_meta()

	var rtl := _make_rich_label(trimmed, enable_keyword_meta)
	vbox.add_child(rtl)
	if enable_keyword_meta:
		_titled_meta_rtl = rtl
		_connect_titled_meta(rtl)

	await _layout_vbox_richtext_sizes(gen)
	if gen != _layout_generation:
		return
	if not _anchor_still_valid(anchor_id):
		_conceal_panel()
		return
	if await _present_tooltip_when_ready(gen, anchor_id, placement):
		# 意图 / 状态：由 Enemy / StatusHandler 发 show-hide，勿轮询（易误判离开）
		if placement == Placement.INTENT_LEFT or not enable_hover_poll:
			return
		_hover_anchor_id = anchor_id
		_hover_placement = placement
		_hover_poll_active = true
		_sync_tooltip_process()


## 地图房间等 Node2D 锚点：用屏幕矩形定位，并随相机滚动每帧更新。
func show_titled_bbcode_at_screen_rect(
	full_bbcode: String,
	screen_anchor: Rect2,
	placement: Placement = Placement.ICON_RIGHT,
	enable_keyword_meta: bool = false
) -> void:
	var trimmed := full_bbcode.strip_edges()
	if trimmed.is_empty():
		return
	_hide_request_serial += 1
	_layout_generation += 1
	var gen := _layout_generation
	_follow_screen_rect = screen_anchor
	_follow_placement = placement
	_cancel_screen_rect_follow()
	_hover_anchor_id = INVALID_ANCHOR_ID
	_stop_hover_poll()
	_conceal_panel()
	_clear_vbox()
	_clear_titled_meta()

	var rtl := _make_rich_label(trimmed, enable_keyword_meta)
	vbox.add_child(rtl)
	if enable_keyword_meta:
		_titled_meta_rtl = rtl
		_connect_titled_meta(rtl)

	await _layout_vbox_richtext_sizes(gen)
	if gen != _layout_generation:
		return
	_position_panel_at_rect(screen_anchor, placement)
	await get_tree().process_frame
	if gen != _layout_generation:
		return
	_reveal_panel()
	_follow_screen_rect_active = true
	_sync_tooltip_process()


func update_follow_screen_rect(screen_anchor: Rect2) -> void:
	_follow_screen_rect = screen_anchor
	if _follow_screen_rect_active and is_instance_valid(panel_root) and panel_root.visible:
		_position_panel_at_rect(_follow_screen_rect, _follow_placement)


func _capture_anchor_id(near_to: Variant) -> int:
	if near_to == null:
		return INVALID_ANCHOR_ID
	if not is_instance_valid(near_to) or not near_to is Control:
		return INVALID_ANCHOR_ID
	return (near_to as Control).get_instance_id()


func _resolve_anchor(anchor_id: int) -> Control:
	if anchor_id < 0:
		return null
	var obj := instance_from_id(anchor_id)
	if obj == null or not is_instance_valid(obj) or not obj is Control:
		return null
	var anchor := obj as Control
	if not anchor.is_inside_tree():
		return null
	return anchor


## anchor_id 为 INVALID 时允许（屏幕居中）；曾有效但已释放则 false。
func _anchor_still_valid(anchor_id: int) -> bool:
	if anchor_id < 0:
		return true
	return _resolve_anchor(anchor_id) != null


## null 表示无锚点（屏幕居中）；仅拒绝已释放或不在树中的 Control。
func _can_position_near_anchor(near_to: Variant) -> bool:
	if near_to == null:
		return true
	if not is_instance_valid(near_to) or not near_to is Control:
		return false
	return (near_to as Control).is_inside_tree()


func _clear_vbox() -> void:
	if not is_instance_valid(vbox):
		return
	for c in vbox.get_children():
		c.queue_free()


func _make_rich_label(text: String, enable_meta: bool, keyword_block: bool = false) -> RichTextLabel:
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = false
	rtl.scroll_active = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_OFF
	rtl.custom_minimum_size = Vector2.ZERO
	rtl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rtl.add_theme_font_size_override("normal_font_size", TOOLTIP_FONT_SIZE)
	rtl.add_theme_font_size_override("bold_font_size", TOOLTIP_FONT_SIZE)
	rtl.text = CardKeywordBbcode.wrap_ascii_digit_runs_bold(
		CardKeywordBbcode.inject_keywords(text) if keyword_block else text
	)
	if enable_meta:
		rtl.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rtl


func _connect_titled_meta(rtl: RichTextLabel) -> void:
	if not rtl.meta_hover_started.is_connected(_on_titled_meta_hover_started):
		rtl.meta_hover_started.connect(_on_titled_meta_hover_started)
	if not rtl.meta_hover_ended.is_connected(_on_titled_meta_hover_ended):
		rtl.meta_hover_ended.connect(_on_titled_meta_hover_ended)


func _clear_titled_meta() -> void:
	if is_instance_valid(_titled_meta_rtl):
		if _titled_meta_rtl.meta_hover_started.is_connected(_on_titled_meta_hover_started):
			_titled_meta_rtl.meta_hover_started.disconnect(_on_titled_meta_hover_started)
		if _titled_meta_rtl.meta_hover_ended.is_connected(_on_titled_meta_hover_ended):
			_titled_meta_rtl.meta_hover_ended.disconnect(_on_titled_meta_hover_ended)
	_titled_meta_rtl = null
	_pending_keyword_restore.clear()


func _on_titled_meta_hover_started(meta: Variant) -> void:
	var s := str(meta)
	if not s.begins_with(CardKeywordBbcode.META_KW_PREFIX):
		return
	var kid := s.substr(CardKeywordBbcode.META_KW_PREFIX.length())
	if CardKeywordBbcode.get_keyword_tooltip_body_bbcode(kid, false).is_empty():
		return
	if is_instance_valid(_titled_meta_rtl):
		_pending_keyword_restore = {
			"bbcode": _titled_meta_rtl.text,
			"source": _active_source,
			"relic": _active_relic,
		}
	show_keyword_blocks(PackedStringArray([kid]), _titled_meta_rtl if is_instance_valid(_titled_meta_rtl) else self)


func _on_titled_meta_hover_ended(meta: Variant) -> void:
	if not str(meta).begins_with(CardKeywordBbcode.META_KW_PREFIX):
		return
	if _pending_keyword_restore.is_empty():
		Events.card_keyword_tooltip_hide.emit()
		return
	var relic: Relic = _pending_keyword_restore.get("relic")
	var source: Control = _pending_keyword_restore.get("source")
	_pending_keyword_restore.clear()
	if relic != null:
		show_tooltip(relic, source)
	else:
		Events.card_keyword_tooltip_hide.emit()


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


func _render_keyword_blocks(seed_ids: PackedStringArray, anchor_id: int, placement: Placement) -> void:
	_layout_generation += 1
	_cancel_screen_rect_follow()
	_conceal_panel()
	Events.card_keyword_tooltip_visible = false
	var gen := _layout_generation
	_clear_vbox()
	_clear_titled_meta()
	_active_relic = null
	_ensure_full_opacity()

	var expanded := _expand_tooltip_ids_depth_first(seed_ids)
	if expanded.is_empty():
		_ensure_full_opacity()
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
		var rtl := _make_rich_label(body, false, true)
		vbox.add_child(rtl)

	if vbox.get_child_count() == 0:
		_ensure_full_opacity()
		return

	vbox.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if get_parent():
		get_parent().move_child(self, -1)

	await _layout_vbox_richtext_sizes(gen)
	if gen != _layout_generation:
		return
	if not _anchor_still_valid(anchor_id):
		_conceal_panel()
		return
	if not await _present_tooltip_when_ready(gen, anchor_id, placement):
		return
	Events.card_keyword_tooltip_visible = true


func _reset_panel_visual_state() -> void:
	_ensure_full_opacity()
	if is_instance_valid(panel_root):
		panel_root.modulate.a = 1.0


func _conceal_panel() -> void:
	_ensure_full_opacity()
	if is_instance_valid(panel_root):
		panel_root.modulate.a = 0.0
		panel_root.global_position = OFFSCREEN_LAYOUT_POS
		panel_root.hide()


func _begin_layout_panel() -> void:
	if not is_instance_valid(panel_root):
		return
	panel_root.modulate.a = 0.0
	panel_root.global_position = OFFSCREEN_LAYOUT_POS
	panel_root.show()
	panel_root.reset_size()


func _reveal_panel() -> void:
	_reset_panel_visual_state()
	if is_instance_valid(panel_root):
		panel_root.show()
	show()


func _present_tooltip_when_ready(gen: int, anchor_id: int, placement: Placement) -> bool:
	if gen != _layout_generation:
		return false
	if not _anchor_still_valid(anchor_id):
		return false
	_position_panel(_resolve_anchor(anchor_id), placement)
	if gen != _layout_generation:
		return false
	await get_tree().process_frame
	if gen != _layout_generation:
		return false
	if not _anchor_still_valid(anchor_id):
		return false
	_reveal_panel()
	return true


func _begin_richtext_intrinsic_measure(rtl: RichTextLabel) -> void:
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_OFF
	rtl.custom_minimum_size = Vector2.ZERO
	rtl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rtl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _prepare_richtext_width(rtl: RichTextLabel) -> void:
	var natural_w := rtl.get_content_width()
	if not is_finite(natural_w) or natural_w < 1.0:
		natural_w = MIN_TEXT_WIDTH
	var box_w := minf(ceilf(natural_w), MAX_TEXT_WIDTH)
	rtl.fit_content = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.custom_minimum_size = Vector2(box_w, 0.0)


func _finalize_richtext_height(rtl: RichTextLabel) -> void:
	var w := rtl.custom_minimum_size.x
	if w < 1.0:
		w = minf(maxf(rtl.get_content_width(), 1.0), MAX_TEXT_WIDTH)
	var h := maxf(1.0, ceilf(rtl.get_content_height()))
	rtl.custom_minimum_size = Vector2(w, h)


func _layout_vbox_richtext_sizes(gen: int) -> void:
	_begin_layout_panel()
	show()

	await get_tree().process_frame
	if gen != _layout_generation:
		return

	for c: Node in vbox.get_children():
		if c is RichTextLabel:
			_begin_richtext_intrinsic_measure(c as RichTextLabel)

	await get_tree().process_frame
	if gen != _layout_generation:
		return

	for c: Node in vbox.get_children():
		if c is RichTextLabel:
			_prepare_richtext_width(c as RichTextLabel)

	await get_tree().process_frame
	if gen != _layout_generation:
		return
	await get_tree().process_frame
	if gen != _layout_generation:
		return

	for c: Node in vbox.get_children():
		if c is RichTextLabel:
			_finalize_richtext_height(c as RichTextLabel)

	panel_root.reset_size()
	await get_tree().process_frame


func _position_panel(near_to: Variant, placement: Placement) -> void:
	if _can_position_near_anchor(near_to):
		var anchor := near_to as Control
		var icon_gap := GAP_FROM_ICON
		if placement == Placement.ICON_RIGHT and anchor.has_meta(&"tooltip_icon_gap"):
			icon_gap = float(anchor.get_meta(&"tooltip_icon_gap"))
		_position_panel_at_rect(anchor.get_global_rect(), placement, false, icon_gap)
	else:
		_position_panel_at_rect(Rect2(), placement, true)


func _position_panel_at_rect(
	gr: Rect2,
	placement: Placement,
	center_fallback: bool = false,
	icon_gap: float = GAP_FROM_ICON
) -> void:
	panel_root.reset_size()
	var viewport := get_viewport()
	if viewport == null:
		return
	var vp := viewport.get_visible_rect()
	var sz := panel_root.size
	if sz.x < 2.0 or sz.y < 2.0:
		sz = panel_root.get_combined_minimum_size()
	var pos: Vector2
	if center_fallback or gr.size.x < 1.0 or gr.size.y < 1.0:
		pos = vp.get_center() - sz * 0.5
	else:
		match placement:
			Placement.RELIC_FLIP:
				pos = Vector2(gr.end.x + GAP_FROM_SOURCE, gr.get_center().y - sz.y * 0.5)
				if pos.x + sz.x > vp.position.x + vp.size.x - VIEWPORT_MARGIN:
					pos.x = gr.position.x - GAP_FROM_SOURCE - sz.x
			Placement.ICON_RIGHT:
				pos = Vector2(gr.end.x + icon_gap, gr.get_center().y - sz.y * 0.5)
			Placement.ICON_LEFT:
				pos = Vector2(gr.position.x - GAP_FROM_ICON - sz.x, gr.get_center().y - sz.y * 0.5)
			Placement.INTENT_LEFT:
				pos = Vector2(
					gr.position.x - GAP_FROM_ICON - sz.x + INTENT_TOOLTIP_OFFSET_X,
					gr.get_center().y - sz.y * 0.5
				)
			_:
				var right_x := gr.end.x + GAP_FROM_SOURCE
				var max_x_allow := vp.position.x + vp.size.x - sz.x - VIEWPORT_MARGIN
				if right_x <= max_x_allow:
					pos = Vector2(right_x, gr.position.y)
				else:
					pos = Vector2(gr.position.x - GAP_FROM_SOURCE - sz.x, gr.position.y)
	pos = _clamp_to_viewport(pos, sz, vp)
	panel_root.global_position = pos


func _clamp_to_viewport(pos: Vector2, sz: Vector2, vp: Rect2) -> Vector2:
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
