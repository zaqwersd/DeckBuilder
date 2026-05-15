class_name CardPreviewListHover
extends Control

## 非手牌场景的卡牌列表预览：依赖 CardMenuUI.use_listing_hover_zoom 做 1.1 倍放大；
## 悬停带词条的卡时通过 Events 显示词条说明；位置由 CardKeywordTooltip 处理（默认卡右侧，贴边则左侧）。

const KEYWORD_TOOLTIP_SCENE := preload("res://scenes/ui/card_keyword_tooltip.tscn")
## Run TopBar 上全局词条 tooltip 的 CanvasLayer.layer；≥ 此层的列表（含 TopBar 牌库 layer=3）用内嵌 tooltip，避免被 is_pointer_ui_obscured 挡住。
const ELEVATED_KEYWORD_TOOLTIP_MIN_CANVAS_LAYER := 3
const MODAL_KEYWORD_TOOLTIP_Z_INDEX := 256

var _kw_tip_menu: CardMenuUI = null
var _kw_tip_ids: PackedStringArray = PackedStringArray()
var _elevated_keyword_tooltip: CardKeywordTooltip = null


## 子类复写：返回参与检测的 CardMenuUI（通常为列表/牌堆网格中的项）。
func gather_listing_card_menus_for_keyword_tooltip() -> Array[CardMenuUI]:
	return []


func _ready() -> void:
	set_process(true)


func _enter_tree() -> void:
	if _wants_elevated_keyword_tooltip():
		_bind_elevated_keyword_tooltip()


func _exit_tree() -> void:
	_unbind_elevated_keyword_tooltip()
	reset_listing_keyword_tooltip_state()


func _wants_elevated_keyword_tooltip() -> bool:
	return Events.effective_canvas_layer_of(self) >= ELEVATED_KEYWORD_TOOLTIP_MIN_CANVAS_LAYER


func _bind_elevated_keyword_tooltip() -> void:
	if _elevated_keyword_tooltip != null:
		return
	_elevated_keyword_tooltip = KEYWORD_TOOLTIP_SCENE.instantiate() as CardKeywordTooltip
	_elevated_keyword_tooltip.z_index = MODAL_KEYWORD_TOOLTIP_Z_INDEX
	_elevated_keyword_tooltip.z_as_relative = false
	_elevated_keyword_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_elevated_keyword_tooltip)
	if not Events.card_keyword_tooltip_show.is_connected(_on_elevated_keyword_tooltip_show):
		Events.card_keyword_tooltip_show.connect(_on_elevated_keyword_tooltip_show)
	if not Events.card_keyword_tooltip_hide.is_connected(_on_elevated_keyword_tooltip_hide):
		Events.card_keyword_tooltip_hide.connect(_on_elevated_keyword_tooltip_hide)


func _unbind_elevated_keyword_tooltip() -> void:
	if _elevated_keyword_tooltip == null:
		return
	if Events.card_keyword_tooltip_show.is_connected(_on_elevated_keyword_tooltip_show):
		Events.card_keyword_tooltip_show.disconnect(_on_elevated_keyword_tooltip_show)
	if Events.card_keyword_tooltip_hide.is_connected(_on_elevated_keyword_tooltip_hide):
		Events.card_keyword_tooltip_hide.disconnect(_on_elevated_keyword_tooltip_hide)
	_elevated_keyword_tooltip.hide_tooltip()
	_elevated_keyword_tooltip.queue_free()
	_elevated_keyword_tooltip = null


func _on_elevated_keyword_tooltip_show(ids: PackedStringArray, near_to: Control) -> void:
	if not is_inside_tree() or not is_visible_in_tree() or _elevated_keyword_tooltip == null:
		return
	_elevated_keyword_tooltip.show_keyword_blocks(ids, near_to)


func _on_elevated_keyword_tooltip_hide() -> void:
	if _elevated_keyword_tooltip != null:
		_elevated_keyword_tooltip.hide_tooltip()


func reset_listing_keyword_tooltip_state() -> void:
	_kw_tip_menu = null
	_kw_tip_ids = PackedStringArray()
	Events.card_keyword_tooltip_hide.emit()


func _process(_delta: float) -> void:
	if Events.is_pointer_ui_obscured_for(self):
		if _kw_tip_menu != null or not _kw_tip_ids.is_empty():
			reset_listing_keyword_tooltip_state()
		return
	if not is_visible_in_tree():
		if _kw_tip_menu != null or not _kw_tip_ids.is_empty():
			reset_listing_keyword_tooltip_state()
		return
	if _kw_tip_menu != null and not is_instance_valid(_kw_tip_menu):
		_kw_tip_menu = null
		_kw_tip_ids = PackedStringArray()
		Events.card_keyword_tooltip_hide.emit()
	var menus := gather_listing_card_menus_for_keyword_tooltip()
	for m in menus:
		if m != null and is_instance_valid(m.visuals) and m.visuals.is_description_kw_meta_active():
			return
	var winner: CardMenuUI = null
	var tip_ids: PackedStringArray = PackedStringArray()
	var best_d2 := INF
	var mp := get_global_mouse_position()
	for m in menus:
		if m == null or not is_instance_valid(m):
			continue
		if not m.is_listing_pointer_over_visuals():
			continue
		if not is_instance_valid(m.visuals):
			continue
		var ids := m.visuals.get_keyword_tooltip_ids()
		if ids.is_empty():
			continue
		var d2 := m.visuals.get_global_rect().get_center().distance_squared_to(mp)
		if d2 < best_d2 - 0.01:
			winner = m
			tip_ids = ids
			best_d2 = d2
	_sync_keyword_tooltip(winner, tip_ids)


func _sync_keyword_tooltip(winner: CardMenuUI, ids: PackedStringArray) -> void:
	if winner == _kw_tip_menu and _kw_tip_ids_equal(ids, _kw_tip_ids):
		return
	_kw_tip_menu = winner
	_kw_tip_ids = ids.duplicate() if winner != null else PackedStringArray()
	if winner == null:
		Events.card_keyword_tooltip_hide.emit()
	else:
		Events.card_keyword_tooltip_show.emit(ids, winner)


func _kw_tip_ids_equal(a: PackedStringArray, b: PackedStringArray) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if a[i] != b[i]:
			return false
	return true
