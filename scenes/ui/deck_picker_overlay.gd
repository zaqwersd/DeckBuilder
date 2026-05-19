class_name DeckPickerOverlay
extends CardGridListing

## 战斗内模态选牌层：高于 HandCardPickOverlay(5) 与 CardPileViews(4)
const BATTLE_MODAL_CANVAS_LAYER := 6

## indices 为卡组真实下标，升序，元素为 int；取消时发空数组（用 Array 避免与 await 的 [] 类型冲突）
signal pick_confirmed(indices: Array)

@onready var grid: GridContainer = %Cards
@onready var confirm: Button = %ConfirmPick
@onready var cancel: Button = %CancelPick
@onready var hint: Label = %HintLabel

var _deck: CardPile
var _picks_required: int = 1
var _validator: Callable = Callable()
var _selected_indices: Array[int] = []
var _index_by_menu: Dictionary = {}
var _allowed_ids: PackedStringArray = PackedStringArray()
## 若有效：用当前已选下标数组（已排序）决定是否显示「确定」；无效时用「选满 picks_required 张」
var _confirm_enabled: Callable = Callable()
var _picker_card_ok: Callable = Callable()
## 为 true 且只需选 1 张时：第一次点选即确认并关闭（营火升级选牌）。
var _auto_confirm_single_pick := false
## 为 true：确认选牌后只发信号不 queue_free，由调用方在后续 UI（如升级流程）结束后再释放本层。
var _defer_free_after_pick := false


func get_card_listing_grid() -> GridContainer:
	return grid


func _ready() -> void:
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_STOP
	confirm.visible = false
	confirm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm.pressed.connect(_on_confirm)
	cancel.pressed.connect(_on_cancel)


func _enter_tree() -> void:
	super._enter_tree()
	Events.begin_pointer_exclusive_ui(self)


func _exit_tree() -> void:
	Events.end_pointer_exclusive_ui(self)
	super._exit_tree()


func setup(
	deck: CardPile,
	picks_required: int,
	validator: Callable = Callable(),
	hint_text: String = "",
	allowed_card_ids: PackedStringArray = PackedStringArray(),
	confirm_enabled: Callable = Callable(),
	picker_card_ok: Callable = Callable(),
	auto_confirm_single_pick: bool = false,
	defer_free_after_pick: bool = false
) -> void:
	_deck = deck
	_picks_required = maxi(1, picks_required)
	_validator = validator
	_allowed_ids = allowed_card_ids
	_confirm_enabled = confirm_enabled
	_picker_card_ok = picker_card_ok
	_auto_confirm_single_pick = auto_confirm_single_pick
	_defer_free_after_pick = defer_free_after_pick
	if hint and not hint_text.is_empty():
		hint.text = hint_text
	_populate()


func _id_is_allowed(card_id: String) -> bool:
	if _allowed_ids.is_empty():
		return true
	for a: String in _allowed_ids:
		if a == card_id:
			return true
	return false


func _populate() -> void:
	if not is_node_ready():
		await ready
	for c: Node in grid.get_children():
		c.queue_free()
	_index_by_menu.clear()
	_selected_indices.clear()
	_update_confirm_visibility()
	if _deck == null:
		return
	for entry: Dictionary in CardGridListing.sorted_card_entries(_deck.cards):
		var c: Card = entry["card"] as Card
		var deck_index: int = int(entry["index"])
		if not _id_is_allowed(c.id):
			continue
		if _picker_card_ok.is_valid() and not bool(_picker_card_ok.call(c)):
			continue
		var menu := create_listing_card_menu()
		grid.add_child(menu)
		menu.card = c
		_index_by_menu[menu] = deck_index
		menu.card_pick_pressed.connect(_on_picker_card_pressed.bind(menu))


func _set_confirm_visible(on: bool) -> void:
	confirm.visible = on
	confirm.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE


func _update_confirm_visibility() -> void:
	if _auto_confirm_single_pick and _picks_required == 1:
		_set_confirm_visible(false)
		return
	var ok := false
	if _confirm_enabled.is_valid():
		var sel: Array = _selected_indices.duplicate()
		sel.sort()
		ok = bool(_confirm_enabled.call(sel))
	else:
		ok = _selected_indices.size() == _picks_required
	_set_confirm_visible(ok)


func _on_picker_card_pressed(menu: Variant, _c: Variant) -> void:
	if not is_inside_tree():
		return
	## bind 把 menu 插在第1位
	var m := menu as CardMenuUI
	if m == null:
		m = _c as CardMenuUI
	if m == null:
		return
	_toggle_pick(m)


func _toggle_pick(menu: CardMenuUI) -> void:
	var idx: int = int(_index_by_menu.get(menu, -1))
	if idx < 0:
		return
	var pos := _selected_indices.find(idx)
	if pos != -1:
		_selected_indices.remove_at(pos)
		menu.set_deck_pick_selected(false)
	else:
		if _selected_indices.size() >= _picks_required:
			return
		_selected_indices.append(idx)
		menu.set_deck_pick_selected(true)
	_selected_indices.sort()
	_update_confirm_visibility()
	_maybe_auto_confirm_single_pick()


func _maybe_auto_confirm_single_pick() -> void:
	if not _auto_confirm_single_pick or _picks_required != 1:
		return
	if _selected_indices.size() != 1:
		return
	var sel: Array = _selected_indices.duplicate()
	sel.sort()
	if _validator.is_valid() and not _validator.call(sel):
		if hint:
			hint.text = "选择不符合要求，请重新选择。"
		var idx0: int = int(sel[0])
		_selected_indices.clear()
		for m: CardMenuUI in _index_by_menu:
			if int(_index_by_menu[m]) == idx0:
				m.set_deck_pick_selected(false)
				break
		_update_confirm_visibility()
		return
	pick_confirmed.emit(sel.duplicate())
	if not _defer_free_after_pick:
		queue_free()


func _on_confirm() -> void:
	if _selected_indices.size() != _picks_required:
		return
	var sel: Array = _selected_indices.duplicate()
	sel.sort()
	if _validator.is_valid() and not _validator.call(sel):
		if hint:
			hint.text = "选择不符合要求，请重新选择。"
		return
	pick_confirmed.emit(sel.duplicate())
	if not _defer_free_after_pick:
		queue_free()


func _on_cancel() -> void:
	pick_confirmed.emit([])
	queue_free()


## 清除所有选中状态（用于从升级界面返回时）
func clear_selection() -> void:
	_selected_indices.clear()
	for menu: CardMenuUI in _index_by_menu:
		menu.set_deck_pick_selected(false)
	_update_confirm_visibility()


static func open_on_tree(tree: SceneTree) -> DeckPickerOverlay:
	var layer := CanvasLayer.new()
	layer.layer = BATTLE_MODAL_CANVAS_LAYER
	tree.root.add_child(layer)
	var scene: PackedScene = preload("res://scenes/ui/deck_picker_overlay.tscn")
	var inst := scene.instantiate() as DeckPickerOverlay
	inst.set_anchors_preset(Control.PRESET_FULL_RECT)
	inst.set_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(inst)
	inst.tree_exiting.connect(
		func() -> void:
			if is_instance_valid(layer):
				layer.queue_free()
	, CONNECT_ONE_SHOT)
	return inst
