class_name CardPreviewListHover
extends Control

## 非手牌场景的卡牌列表预览：依赖 CardMenuUI.use_listing_hover_zoom 做 1.1 倍放大；
## 悬停带词条的卡时通过 Events 显示词条说明；位置由 CardKeywordTooltip 处理（默认卡右侧，贴边则左侧）。

var _kw_tip_menu: CardMenuUI = null
var _kw_tip_ids: PackedStringArray = PackedStringArray()


## 子类复写：返回参与检测的 CardMenuUI（通常为列表/牌堆网格中的项）。
func gather_listing_card_menus_for_keyword_tooltip() -> Array[CardMenuUI]:
	return []


func _ready() -> void:
	set_process(true)


func _exit_tree() -> void:
	reset_listing_keyword_tooltip_state()


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
