class_name HandCardPickOverlay
extends CanvasLayer

## 战斗内从「真实手牌 Hand」中自选若干张牌：与牌堆视图同色的幕布、将 Hand 抬到最上层且保持全局位置；
## `required_count`：需选张数；`filter_condition`：`func(card: Card) -> bool`，空 Callable 表示不过滤。
## 布局由场景控制（在编辑器里改最直观）：
## `PickColumn`：整屏边距（MarginContainer 的 theme margin）。
## `MainVBox`：自上而下依次为 `TitleLabel` → `SelectionBand`（勾选区最小高度）→ `ConfirmButton` → `HandBand`（手牌区最小高度）。
## `SelectionBand/SelectionCenter/SelectionRow`：已选牌横向居中排列；脚本只调 `separation`。
## 手牌在选牌期间挂到 `Root` 顶层，按进入选牌前在战斗场景中的 `global_rect` 对齐，不塞进 `HandHost` 布局。

signal selection_finished(confirmed: bool, selected_cards: Array[Card])

const DIM_COLOR := Color(0, 0, 0, 0.65098)
const CARD_SPACING_PX := 220.0
## 选满并显示「确定」时，手牌条在 HandHost 内相对基准位置下移
const HAND_DROP_WHEN_CONFIRM_PX := 50.0
## MainPanel 在 210×220 内边距 (12,29,4,8)：可见卡面中心比 CardUI 框中心偏 (+4, +10.5)
const SELECTION_MAIN_PANEL_INSETS := Vector4(12.0, 29.0, 4.0, 8.0)
## 抵消场景里 SelectionCenter.offset_top = 40 造成的整体下移
const SELECTION_CENTER_LAYOUT_OFFSET := Vector2(-10.0, -40.0)
## 在自动居中后再微调：负 x 向左，负 y 向上
const SELECTION_BAND_FINE_NUDGE := Vector2(-10.0, -150.0)

@onready var _root: Control = $Root
@onready var _dim: ColorRect = $Root/Dim
@onready var _title: Label = %TitleLabel
@onready var _selection_center: CenterContainer = %SelectionCenter
@onready var _selection_row: HBoxContainer = %SelectionRow
@onready var _confirm_wrap: MarginContainer = %ConfirmWrap
@onready var _confirm: Button = %ConfirmButton
@onready var _hand_host: Control = %HandHost

var _hand: Hand
var _required: int = 1
var _filter: Callable = Callable()

var _hand_parent: Node = null
var _hand_index: int = 0
var _hand_saved_pos: Vector2 = Vector2.ZERO
var _hand_saved_global_rect: Rect2 = Rect2()
var _hand_saved_layout: Dictionary = {}
var _pending_hand_drop_y: float = 0.0

var _selected: Array[CardUI] = []
var _slot_by_cui: Dictionary = {}
var _saved_playable: Dictionary = {}
var _saved_slot_visible: Dictionary = {}
var _saved_cui_visible: Dictionary = {}

var _pointer_registered := false
var _closed := false
var _selection_band_nudge: Vector2 = Vector2.ZERO
var _allow_cancel: bool = true  ## 是否允许ESC取消，默认为true
var _pick_input_enabled := false  ## 打开层后须等当前按键松开，避免打出牌的同一次点击误选


func _ready() -> void:
	add_to_group("hand_card_pick_overlay")
	layer = 5
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.color = DIM_COLOR
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_wrap.hide()
	_confirm.pressed.connect(_on_confirm_pressed)
	visibility_changed.connect(_on_visibility_pointer_exclusive)
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _closed or not is_instance_valid(_hand) or not _pick_input_enabled:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var cui := _find_card_ui_at_pick_collision(mb.global_position)
	if cui == null:
		return
	if not _hand.is_ancestor_of(cui) and cui.get_parent() != _selection_row:
		return
	if _try_handle_pick_event(cui, mb):
		get_viewport().set_input_as_handled()


func _find_card_ui_at_pick_collision(global_xy: Vector2) -> CardUI:
	var from_hand := _find_hand_card_ui_at_global_pick(global_xy)
	if from_hand != null:
		return from_hand
	for cui in _selected:
		if not is_instance_valid(cui) or not is_instance_valid(cui.card_visuals):
			continue
		var r := cui.card_visuals.get_pick_collision_global_rect()
		if r.has_point(global_xy):
			return cui
	return null


func _find_hand_card_ui_at_global_pick(global_xy: Vector2) -> CardUI:
	for slot in _hand.get_children():
		if not slot.visible:
			continue
		var c := _hand.get_card_ui_in_slot(slot)
		if c == null or not c.visible:
			continue
		if not is_instance_valid(c.card_visuals):
			continue
		var r := c.card_visuals.get_pick_collision_global_rect()
		if r.has_point(global_xy):
			return c
	return null


func _on_visibility_pointer_exclusive() -> void:
	if is_instance_valid(_root) and _root.is_visible_in_tree():
		if not _pointer_registered:
			Events.begin_pointer_exclusive_ui(self)
			_pointer_registered = true
	else:
		if _pointer_registered:
			Events.end_pointer_exclusive_ui(self)
			_pointer_registered = false


func start_pick(
	hand: Hand,
	required_count: int = 1,
	filter_condition: Callable = Callable(),
	title: String = "选择要消耗的卡牌",
	allow_cancel: bool = true
) -> void:
	_required = maxi(1, required_count)
	_filter = filter_condition
	_allow_cancel = allow_cancel
	_pick_input_enabled = false
	_closed = false
	_selected.clear()
	_slot_by_cui.clear()
	_saved_playable.clear()
	_saved_slot_visible.clear()
	_saved_cui_visible.clear()

	_title.text = title
	_confirm_wrap.hide()

	_hand = hand
	if not is_instance_valid(_hand) or not _hand.is_inside_tree():
		_finalize_teardown(false, [])
		return

	## 统计有效卡牌数量
	var valid_cards: Array[CardUI] = []
	for slot in _hand.get_children():
		var cui := _hand.get_card_ui_in_slot(slot)
		if cui == null or cui.card == null:
			continue
		if cui.modulate.a <= 0.01:
			continue
		if filter_condition.is_valid() and not filter_condition.call(cui.card):
			continue
		valid_cards.append(cui)

	## 如果没有有效卡牌，直接取消
	if valid_cards.is_empty():
		_finalize_teardown(false, [])
		return

	## 可选牌数量不超过需求时，无需进入选牌界面（如取舍仅 1 张可消耗手牌）。
	if valid_cards.size() <= _required:
		var auto_picked: Array[Card] = []
		for cui in valid_cards:
			auto_picked.append(cui.card)
		call_deferred("_confirm_auto_pick", auto_picked)
		return

	_hand_parent = _hand.get_parent()
	_hand_index = _hand.get_index()
	_hand_saved_global_rect = _hand.get_global_rect()
	_hand_saved_pos = _hand.global_position
	_save_hand_layout_for_pick()

	_hand_parent.remove_child(_hand)
	_root.add_child(_hand)
	_root.move_child(_hand, _root.get_child_count() - 1)
	_apply_hand_in_pick_overlay()

	_apply_filter_visibility()
	_snapshot_and_disable_playable_for_pick()
	if _saved_playable.is_empty():
		_finalize_teardown(false, [])
		return

	_selection_band_nudge = Vector2.ZERO
	if is_instance_valid(_selection_center):
		_selection_center.position = Vector2.ZERO
	show()
	_schedule_pick_column_layout(false)
	call_deferred("_arm_pick_input_after_pointer_up")


func _arm_pick_input_after_pointer_up() -> void:
	if _closed or not is_inside_tree():
		return
	while Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not _closed:
		await get_tree().process_frame
	if _closed:
		return
	_pick_input_enabled = true


func _confirm_auto_pick(cards: Array[Card]) -> void:
	if _closed:
		return
	_finalize_teardown(true, cards)


func _apply_filter_visibility() -> void:
	for slot in _hand.get_children():
		_saved_slot_visible[slot] = slot.visible
		var cui := _hand.get_card_ui_in_slot(slot)
		if cui == null or cui.card == null:
			slot.visible = false
			continue
		var ok := true
		if _filter.is_valid():
			ok = bool(_filter.call(cui.card))
		slot.visible = ok
		_saved_cui_visible[cui] = cui.visible
		if not ok:
			cui.visible = false
		else:
			cui.visible = true
	_hand._request_reflow_hand_bar()


func _snapshot_and_disable_playable_for_pick() -> void:
	for slot in _hand.get_children():
		if not slot.visible:
			continue
		var cui := _hand.get_card_ui_in_slot(slot)
		if cui == null or cui.card == null:
			continue
		if cui.modulate.a <= 0.01:
			continue
		_saved_playable[cui] = cui.playable
		cui.set_meta(CardUI.HAND_PICK_DELEGATE_META, _make_pick_delegate(cui))
		cui.playable = false
		if is_instance_valid(cui.card_visuals):
			cui.card_visuals.icon.modulate = Color(1, 1, 1, 1)
		cui.call_deferred("sync_gui_rect_to_pick_collision")


func _make_pick_delegate(cui: CardUI) -> Callable:
	return func(ev: InputEvent) -> bool:
		return _try_handle_pick_event(cui, ev)


func _try_handle_pick_event(cui: CardUI, event: InputEvent) -> bool:
	if not _pick_input_enabled or _closed or not (event is InputEventMouseButton):
		return false
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return false

	if _selected.has(cui):
		_deselect_card_ui(cui)
		get_viewport().set_input_as_handled()
		return true

	if _selected.size() >= _required:
		return false

	if cui.get_parent() == _selection_row and not _selected.has(cui):
		return false

	if _filter.is_valid() and not bool(_filter.call(cui.card)):
		return false

	_select_card_ui(cui)
	get_viewport().set_input_as_handled()
	return true


func _select_card_ui(cui: CardUI) -> void:
	var slot := cui.get_parent()
	if slot == null:
		return
	cui.force_hand_hover_visuals_off()
	cui.position = Vector2.ZERO
	cui.scale = Vector2.ONE
	_slot_by_cui[cui] = slot
	if slot is Control and is_instance_valid(_hand):
		_hand.collapse_slot_for_pick(slot as Control)
	slot.remove_child(cui)
	_selection_row.add_child(cui)
	cui.visible = true
	_selected.append(cui)
	_layout_card_ui_in_selection_row(cui)
	if _selected.size() >= _required:
		call_deferred("_deferred_show_confirm_and_layout")
	else:
		_schedule_pick_column_layout(true)


func _deferred_show_confirm_and_layout() -> void:
	if _closed:
		return
	_confirm_wrap.show()
	_sync_hand_pick_confirm_offset()
	_schedule_pick_column_layout(true)


func _deselect_card_ui(cui: CardUI) -> void:
	var idx := _selected.find(cui)
	if idx < 0:
		return
	_selected.remove_at(idx)
	var slot: Variant = _slot_by_cui.get(cui, null)
	if is_instance_valid(slot) and slot is Node:
		if cui.get_parent() == _selection_row:
			_selection_row.remove_child(cui)
		else:
			cui.get_parent().remove_child(cui)
		(slot as Node).add_child(cui)
		cui.position = Vector2.ZERO
		cui.scale = Vector2.ONE
		if slot is Control and is_instance_valid(_hand):
			_hand.restore_slot_after_pick(slot as Control)
			cui.visible = true
		if is_instance_valid(_hand):
			_hand.sync_card_ui_after_reparent_to_slot(cui)
	_slot_by_cui.erase(cui)
	if _selected.size() < _required:
		_confirm_wrap.hide()
		_sync_hand_pick_confirm_offset()
	_schedule_pick_column_layout(false)


func _schedule_pick_column_layout(_animate: bool = false) -> void:
	if _closed:
		return
	call_deferred("_layout_pick_column_pass1")


func _layout_pick_column_pass1() -> void:
	if _closed:
		return
	call_deferred("_layout_pick_column_execute")


func _layout_pick_column_execute() -> void:
	if _closed or not is_instance_valid(_hand):
		return
	_layout_pick_column_impl()
	call_deferred("_deferred_align_selection_to_viewport_center")


## MainPanel 几何中心相对 CardUI 外框中心的偏移（应加在 card_visuals.position 上，往左上拉）。
func _selection_visual_correction(card_size: Vector2) -> Vector2:
	var panel_size := Vector2(
		card_size.x - SELECTION_MAIN_PANEL_INSETS.x - SELECTION_MAIN_PANEL_INSETS.z,
		card_size.y - SELECTION_MAIN_PANEL_INSETS.y - SELECTION_MAIN_PANEL_INSETS.w
	)
	var panel_center := Vector2(SELECTION_MAIN_PANEL_INSETS.x, SELECTION_MAIN_PANEL_INSETS.y) + panel_size * 0.5
	return card_size * 0.5 - panel_center


## 勾选区：用与场景一致的 210×220，CardVisuals 同尺寸，避免 0.7 手牌缩放后子节点仍 210×220 被裁切/挤扁。
func _layout_card_ui_in_selection_row(cui: CardUI) -> void:
	if not is_instance_valid(cui):
		return
	var sz := Hand.CARD_UI_BASE_SIZE
	cui.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	cui.position = Vector2.ZERO
	cui.scale = Vector2.ONE
	cui.rotation = 0.0
	cui.pivot_offset = Vector2.ZERO
	cui.offset_left = 0.0
	cui.offset_top = 0.0
	cui.offset_right = sz.x
	cui.offset_bottom = sz.y
	cui.custom_minimum_size = sz
	cui.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cui.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not is_instance_valid(cui.card_visuals):
		return
	var cv := cui.card_visuals
	cv.scale = Vector2.ONE
	cv.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	cv.offset_left = 0.0
	cv.offset_top = 0.0
	cv.offset_right = sz.x
	cv.offset_bottom = sz.y
	cv.position = _selection_visual_correction(sz)


func _apply_selection_center_layout_offset() -> void:
	if not is_instance_valid(_selection_center):
		return
	_selection_center.offset_left = SELECTION_CENTER_LAYOUT_OFFSET.x
	_selection_center.offset_top = SELECTION_CENTER_LAYOUT_OFFSET.y
	_selection_center.offset_right = SELECTION_CENTER_LAYOUT_OFFSET.x
	_selection_center.offset_bottom = SELECTION_CENTER_LAYOUT_OFFSET.y


func _deferred_align_selection_to_viewport_center() -> void:
	if _closed or _selected.is_empty() or not is_instance_valid(_selection_row) or not is_inside_tree():
		return
	var vp := get_viewport()
	if vp == null:
		return
	var vp_c := vp.get_visible_rect().get_center()
	var row_r := _selection_row.get_global_rect()
	if row_r.size.x < 1.0 or row_r.size.y < 1.0:
		return
	_selection_band_nudge = vp_c - row_r.get_center() + SELECTION_BAND_FINE_NUDGE
	if is_instance_valid(_selection_center):
		_selection_center.position = _selection_band_nudge


func _layout_pick_column_impl() -> void:
	if _closed or not is_instance_valid(_hand):
		return
	_apply_selection_center_layout_offset()
	_hand._request_reflow_hand_bar()

	_selection_row.add_theme_constant_override(
		"separation",
		maxi(0, int(round(CARD_SPACING_PX - Hand.CARD_UI_BASE_SIZE.x)))
	)

	for cui_sel in _selected:
		if not is_instance_valid(cui_sel):
			continue
		_layout_card_ui_in_selection_row(cui_sel)
	_sync_hand_pick_confirm_offset()


func request_hand_global_realign() -> void:
	if _closed or not visible or not is_instance_valid(_hand):
		return
	_sync_hand_pick_confirm_offset()


func _sync_hand_pick_confirm_offset() -> void:
	if not is_instance_valid(_hand) or _hand.get_parent() != _root:
		return
	var drop := HAND_DROP_WHEN_CONFIRM_PX if _selected.size() >= _required and _confirm_wrap.visible else 0.0
	_schedule_hand_global_align(drop)


func _schedule_hand_global_align(extra_drop_y: float = 0.0) -> void:
	if _closed or not is_instance_valid(_hand):
		return
	_pending_hand_drop_y = extra_drop_y
	call_deferred("_deferred_align_hand_global")


func _deferred_align_hand_global() -> void:
	if _closed or not is_instance_valid(_hand):
		return
	_align_hand_to_saved_global_rect(_pending_hand_drop_y)


func _align_hand_to_saved_global_rect(extra_drop_y: float = 0.0) -> void:
	if not is_instance_valid(_hand) or _hand.get_parent() != _root:
		return
	var saved := _hand_saved_global_rect
	saved.position.y += extra_drop_y
	var sz := _hand.size
	if sz.x < 1.0 or sz.y < 1.0:
		sz = _hand.get_combined_minimum_size()
	var saved_center_x := saved.position.x + saved.size.x * 0.5
	var saved_bottom_y := saved.end.y
	_hand.global_position = Vector2(
		saved_center_x - sz.x * 0.5,
		saved_bottom_y - sz.y
	)


func _on_confirm_pressed() -> void:
	if _closed:
		return
	var cards: Array[Card] = []
	for cui in _selected:
		if cui.card:
			cards.append(cui.card)
	while not _selected.is_empty():
		_deselect_card_ui(_selected[0])
	_finalize_teardown(true, cards)


func _input(event: InputEvent) -> void:
	if not visible or _closed:
		return
	if event.is_action_pressed("ui_cancel"):
		if not _allow_cancel:
			return  ## 强制选择，不可取消
		while not _selected.is_empty():
			_deselect_card_ui(_selected[0])
		_finalize_teardown(false, [])


func _save_hand_layout_for_pick() -> void:
	if not is_instance_valid(_hand):
		return
	_hand_saved_layout = {
		"anchor_left": _hand.anchor_left,
		"anchor_top": _hand.anchor_top,
		"anchor_right": _hand.anchor_right,
		"anchor_bottom": _hand.anchor_bottom,
		"offset_left": _hand.offset_left,
		"offset_top": _hand.offset_top,
		"offset_right": _hand.offset_right,
		"offset_bottom": _hand.offset_bottom,
		"grow_horizontal": _hand.grow_horizontal,
		"grow_vertical": _hand.grow_vertical,
		"position": _hand.position,
		"scale": _hand.scale,
	}


func _apply_hand_in_pick_overlay() -> void:
	if not is_instance_valid(_hand):
		return
	_hand.begin_pick_overlay_external_positioning()
	_hand.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hand.anchor_left = 0.0
	_hand.anchor_top = 0.0
	_hand.anchor_right = 0.0
	_hand.anchor_bottom = 0.0
	_hand.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hand.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hand.scale = Vector2.ONE
	_hand.offset_left = 0.0
	_hand.offset_top = 0.0
	_hand.offset_right = 0.0
	_hand.offset_bottom = 0.0
	_hand._request_reflow_hand_bar()
	_schedule_hand_global_align(0.0)


func _restore_hand_layout_after_pick() -> void:
	if not is_instance_valid(_hand):
		return
	_hand.end_pick_overlay_external_positioning()
	if _hand_saved_layout.is_empty():
		return
	_hand.anchor_left = float(_hand_saved_layout.get("anchor_left", _hand.anchor_left))
	_hand.anchor_top = float(_hand_saved_layout.get("anchor_top", _hand.anchor_top))
	_hand.anchor_right = float(_hand_saved_layout.get("anchor_right", _hand.anchor_right))
	_hand.anchor_bottom = float(_hand_saved_layout.get("anchor_bottom", _hand.anchor_bottom))
	_hand.offset_left = float(_hand_saved_layout.get("offset_left", _hand.offset_left))
	_hand.offset_top = float(_hand_saved_layout.get("offset_top", _hand.offset_top))
	_hand.offset_right = float(_hand_saved_layout.get("offset_right", _hand.offset_right))
	_hand.offset_bottom = float(_hand_saved_layout.get("offset_bottom", _hand.offset_bottom))
	_hand.grow_horizontal = int(_hand_saved_layout.get("grow_horizontal", _hand.grow_horizontal))
	_hand.grow_vertical = int(_hand_saved_layout.get("grow_vertical", _hand.grow_vertical))
	_hand.position = _hand_saved_layout.get("position", _hand.position) as Vector2
	_hand.scale = _hand_saved_layout.get("scale", _hand.scale) as Vector2
	_hand_saved_layout.clear()


func _reparent_hand_back() -> void:
	if not is_instance_valid(_hand):
		return
	var pick_parent := _hand.get_parent()
	if pick_parent == _root:
		_root.remove_child(_hand)
	elif pick_parent == _hand_host:
		_hand_host.remove_child(_hand)
	else:
		return
	if is_instance_valid(_hand_parent):
		_hand_parent.add_child(_hand)
		var max_i := maxi(_hand_parent.get_child_count() - 1, 0)
		_hand_parent.move_child(_hand, clampi(_hand_index, 0, max_i))
	_restore_hand_layout_after_pick()
	_hand._request_reflow_hand_bar()


func _finalize_teardown(confirmed: bool, cards: Array[Card]) -> void:
	if _closed:
		return
	_closed = true

	_clear_delegates_and_restore_playable()
	_restore_slot_visibility()
	_reparent_hand_back()

	if is_instance_valid(_hand):
		_hand._request_reflow_hand_bar()

	selection_finished.emit(confirmed, cards)
	hide()
	queue_free()


func _clear_delegates_and_restore_playable() -> void:
	var keys: Array = _saved_playable.keys()
	for cui in keys:
		if is_instance_valid(cui) and cui.has_meta(CardUI.HAND_PICK_DELEGATE_META):
			cui.remove_meta(CardUI.HAND_PICK_DELEGATE_META)
	for cui in keys:
		if not is_instance_valid(cui):
			continue
		cui.playable = bool(_saved_playable[cui])
		if is_instance_valid(_hand) and is_instance_valid(cui.hand_slot) and cui.get_parent() == cui.hand_slot:
			_hand.sync_card_ui_after_reparent_to_slot(cui)
	_saved_playable.clear()


func _restore_slot_visibility() -> void:
	for slot in _saved_slot_visible.keys():
		if is_instance_valid(slot):
			slot.visible = bool(_saved_slot_visible[slot])
	for cui in _saved_cui_visible.keys():
		if is_instance_valid(cui):
			cui.visible = bool(_saved_cui_visible[cui])
	_saved_slot_visible.clear()
	_saved_cui_visible.clear()


static func open_on_tree(
	tree: SceneTree,
	hand: Hand,
	required_count: int = 1,
	filter_condition: Callable = Callable(),
	title: String = "选择要消耗的卡牌",
	allow_cancel: bool = true
) -> HandCardPickOverlay:
	var scene: PackedScene = preload("res://scenes/ui/hand_card_pick_overlay.tscn")
	var inst := scene.instantiate() as HandCardPickOverlay
	tree.root.add_child(inst)
	inst.start_pick(hand, required_count, filter_condition, title, allow_cancel)
	return inst
