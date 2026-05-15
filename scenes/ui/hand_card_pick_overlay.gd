class_name HandCardPickOverlay
extends CanvasLayer

## 战斗内从「真实手牌 Hand」中自选若干张牌：与牌堆视图同色的幕布、将 Hand 抬到最上层且保持全局位置；
## `required_count`：需选张数；`filter_condition`：`func(card: Card) -> bool`，空 Callable 表示不过滤。
## 布局由场景控制（在编辑器里改最直观）：
## `PickColumn`：整屏边距（MarginContainer 的 theme margin）。
## `MainVBox`：自上而下依次为 `TitleLabel` → `SelectionBand`（勾选区最小高度）→ `ConfirmButton` → `HandBand`（手牌区最小高度）。
## `SelectionBand/SelectionCenter/SelectionRow`：已选牌横向居中排列；脚本只调 `separation`。
## `HandBand/HandHost`：放手牌根节点；脚本只把手牌条在 `HandHost` 内水平居中。

signal selection_finished(confirmed: bool, selected_cards: Array[Card])

const DIM_COLOR := Color(0, 0, 0, 0.65098)
const CARD_SPACING_PX := 220.0
const FLY_SEC := 0.28

@onready var _root: Control = $Root
@onready var _dim: ColorRect = $Root/Dim
@onready var _title: Label = %TitleLabel
@onready var _selection_row: HBoxContainer = %SelectionRow
@onready var _confirm: Button = %ConfirmButton
@onready var _hand_host: Control = %HandHost

var _hand: Hand
var _required: int = 1
var _filter: Callable = Callable()

var _hand_parent: Node = null
var _hand_index: int = 0
var _hand_saved_pos: Vector2 = Vector2.ZERO

var _selected: Array[CardUI] = []
var _slot_by_cui: Dictionary = {}
var _saved_playable: Dictionary = {}
var _saved_slot_visible: Dictionary = {}
var _saved_cui_visible: Dictionary = {}

var _pointer_registered := false
var _closed := false
var _pending_layout_animate := false


func _ready() -> void:
	layer = 5
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.color = DIM_COLOR
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm.hide()
	_confirm.pressed.connect(_on_confirm_pressed)
	visibility_changed.connect(_on_visibility_pointer_exclusive)
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _closed or not is_instance_valid(_hand):
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
	title: String = "选择要消耗的卡牌"
) -> void:
	_required = maxi(1, required_count)
	_filter = filter_condition
	_closed = false
	_selected.clear()
	_slot_by_cui.clear()
	_saved_playable.clear()
	_saved_slot_visible.clear()
	_saved_cui_visible.clear()

	_title.text = title
	_confirm.hide()

	_hand = hand
	if not is_instance_valid(_hand) or not _hand.is_inside_tree():
		_finalize_teardown(false, [])
		return

	_hand_parent = _hand.get_parent()
	_hand_index = _hand.get_index()
	_hand_saved_pos = _hand.global_position

	_hand_parent.remove_child(_hand)
	_hand_host.add_child(_hand)
	_hand.position = Vector2.ZERO
	_hand.scale = Vector2.ONE

	_apply_filter_visibility()
	_snapshot_and_disable_playable_for_pick()
	if _saved_playable.is_empty():
		_finalize_teardown(false, [])
		return

	show()
	_schedule_pick_column_layout(false)


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
	if _closed or not (event is InputEventMouseButton):
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
	_slot_by_cui[cui] = slot
	if slot is Control:
		slot.set_meta(Hand.META_SLOT_DRAG_TEMP_EMPTY, true)
	slot.remove_child(cui)
	_selection_row.add_child(cui)
	_selected.append(cui)
	if _selected.size() >= _required:
		call_deferred("_deferred_show_confirm_and_layout")
	else:
		_schedule_pick_column_layout(true)


func _deferred_show_confirm_and_layout() -> void:
	if _closed:
		return
	_confirm.show()
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
		if slot is Control and (slot as Control).has_meta(Hand.META_SLOT_DRAG_TEMP_EMPTY):
			(slot as Control).remove_meta(Hand.META_SLOT_DRAG_TEMP_EMPTY)
		if is_instance_valid(_hand):
			_hand.sync_card_ui_after_reparent_to_slot(cui)
	_slot_by_cui.erase(cui)
	if _selected.size() < _required:
		_confirm.hide()
	_schedule_pick_column_layout(false)


func _schedule_pick_column_layout(animate: bool) -> void:
	if _closed:
		return
	_pending_layout_animate = animate
	call_deferred("_layout_pick_column_pass1")


func _layout_pick_column_pass1() -> void:
	if _closed:
		return
	call_deferred("_layout_pick_column_execute")


func _layout_pick_column_execute() -> void:
	if _closed or not is_instance_valid(_hand):
		return
	_layout_pick_column_impl(_pending_layout_animate)


func _layout_pick_column_impl(animate: bool) -> void:
	if _closed or not is_instance_valid(_hand):
		return
	_hand._request_reflow_hand_bar()

	var host_w := _hand_host.size.x
	var need_w := _hand.get_minimum_size().x
	_hand.position.x = maxf(0.0, (host_w - need_w) * 0.5)
	_hand.position.y = 0.0

	var cw := Hand.CARD_UI_BASE_SIZE.x * _hand.display_scale
	_selection_row.add_theme_constant_override("separation", maxi(0, int(round(CARD_SPACING_PX - cw))))

	for cui_sel in _selected:
		if not is_instance_valid(cui_sel):
			continue
		if animate:
			cui_sel.scale = Vector2(0.94, 0.94)
			var tw := cui_sel.create_tween().set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
			tw.tween_property(cui_sel, "scale", Vector2.ONE, FLY_SEC)
		else:
			cui_sel.scale = Vector2.ONE
		cui_sel.call_deferred("sync_gui_rect_to_pick_collision")


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
		while not _selected.is_empty():
			_deselect_card_ui(_selected[0])
		_finalize_teardown(false, [])


func _reparent_hand_back() -> void:
	if not is_instance_valid(_hand):
		return
	if _hand.get_parent() == _hand_host:
		_hand_host.remove_child(_hand)
		if is_instance_valid(_hand_parent):
			_hand_parent.add_child(_hand)
			var max_i := maxi(_hand_parent.get_child_count() - 1, 0)
			_hand_parent.move_child(_hand, clampi(_hand_index, 0, max_i))
		_hand.global_position = _hand_saved_pos


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
	title: String = "选择要消耗的卡牌"
) -> HandCardPickOverlay:
	var scene: PackedScene = preload("res://scenes/ui/hand_card_pick_overlay.tscn")
	var inst := scene.instantiate() as HandCardPickOverlay
	tree.root.add_child(inst)
	inst.start_pick(hand, required_count, filter_condition, title)
	return inst
