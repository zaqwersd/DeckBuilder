class_name Hand
extends HBoxContainer

const CARD_UI_SCENE := preload("res://scenes/card_ui/card_ui.tscn")
## 与 `card_ui.tscn` 中 CardUI 的 `custom_minimum_size` 一致
const CARD_UI_BASE_SIZE := Vector2(210, 220)

@export var player: Player
@export var char_stats: CharacterStats

## 在脚本中修改；非 @export，避免战斗场景把检查器值写进 .tscn 后永远覆盖这里。
## 注意：不要用子 Control 的 `scale` 做手牌缩放——`HBoxContainer` 排序时会调用
## `Container.fit_child_in_rect()`，其中固定执行 `set_scale(Vector2.ONE)`，只有靠后的
## 一帧里 deferred 回调可能让你误以为「只有一张牌吃到了 scale」。
var display_scale: float = 0.7
## 0 = 牌与牌之间不留缝；整块手牌宽度随张数收缩后由 `_reflow_hand_bar` 水平居中
var card_separation: int = 0

## 卡牌拖向 ui_layer 时槽会暂时无子节点，勿当作「空槽」删除
const META_SLOT_DRAG_TEMP_EMPTY := &"_hand_slot_drag_temp_empty"

## 整条手牌栏整体上移（相对场景里写的 offset_top/bottom）。在 `_ready` 应用，保证进战斗必生效。
const HAND_BAR_RAISE_PX := 50.0

## 无牌时恢复场景里原来的底边手牌条半宽（offset 对称用）
var _empty_bar_half_width: float = 337.5

## 同帧内可多次请求；正在 reflow 时只打脏标记，结束后立刻再跑一轮，避免整帧 deferred
var _reflow_running: bool = false
var _reflow_dirty: bool = false

## 手牌词条 tooltip：仅当鼠标与「当前这张牌」重合时显示，由本节点统一发 Events，避免每帧重复 emit
var _kw_tip_card: CardUI = null
var _kw_tip_ids: PackedStringArray = PackedStringArray()

## 本帧鼠标下手牌「主目标」：扩展命中区重叠的牌中取距牌心最近者（不依赖 gui_get_hovered_control / z 同步顺序）。
var _mouse_foremost_hand_card: CardUI = null


func _enter_tree() -> void:
	_apply_card_separation()


func _ready() -> void:
	child_entered_tree.connect(_on_child_entered_tree)
	child_exiting_tree.connect(_on_child_exiting_tree)
	_empty_bar_half_width = absf(offset_left)
	offset_top -= HAND_BAR_RAISE_PX
	offset_bottom -= HAND_BAR_RAISE_PX
	# 底边锚点居中时：必须同步 offset 宽度 = 内容宽，否则场景固定 ±337.5 会一直占满一条宽带，牌看起来不靠拢
	alignment = BoxContainer.ALIGNMENT_CENTER
	_apply_card_separation()
	_refresh_hand_card_scales()
	_request_reflow_hand_bar()
	set_process(true)
	process_priority = -128


func get_mouse_foremost_hand_card() -> CardUI:
	return _mouse_foremost_hand_card


func _update_mouse_foremost_hand_card() -> void:
	_mouse_foremost_hand_card = null
	var mp := get_global_mouse_position()
	var best: CardUI = null
	var best_d2 := INF
	var best_si := -999999
	for slot in get_children():
		var c := get_card_ui_in_slot(slot)
		if c == null or c.disabled:
			continue
		if c.get_parent() != slot:
			continue
		var sm := c.card_state_machine
		if sm == null or sm.current_state == null:
			continue
		if sm.current_state.state != CardState.State.BASE:
			continue
		if not c.is_hand_hover_hit_overlapping():
			continue
		var d2 := c.get_hand_hover_hit_global_rect().get_center().distance_squared_to(mp)
		var si := slot.get_index()
		if d2 < best_d2 - 0.01:
			best = c
			best_d2 = d2
			best_si = si
		elif is_equal_approx(d2, best_d2) and si > best_si:
			best = c
			best_d2 = d2
			best_si = si
	_mouse_foremost_hand_card = best


func _exit_tree() -> void:
	if _kw_tip_card != null:
		_kw_tip_card = null
		_kw_tip_ids = PackedStringArray()
		Events.card_keyword_tooltip_hide.emit()


func _process(_delta: float) -> void:
	_update_mouse_foremost_hand_card()
	var tip_card: CardUI = null
	var tip_ids: PackedStringArray = PackedStringArray()
	for slot in get_children():
		var card := get_card_ui_in_slot(slot)
		if not card:
			continue
		card.sync_hand_hover_presentation()
		if tip_card == null and card.is_hand_pointer_over_this_card() and is_instance_valid(card.card_visuals):
			var ids := card.card_visuals.get_keyword_tooltip_ids()
			if not ids.is_empty():
				tip_card = card
				tip_ids = ids
	_sync_hand_keyword_tooltip(tip_card, tip_ids)


func _kw_tip_ids_equal(a: PackedStringArray, b: PackedStringArray) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if a[i] != b[i]:
			return false
	return true


func _sync_hand_keyword_tooltip(winner: CardUI, ids: PackedStringArray) -> void:
	if winner == _kw_tip_card and _kw_tip_ids_equal(ids, _kw_tip_ids):
		return
	_kw_tip_card = winner
	_kw_tip_ids = ids.duplicate() if winner != null else PackedStringArray()
	if winner == null:
		Events.card_keyword_tooltip_hide.emit()
	else:
		Events.card_keyword_tooltip_show.emit(ids, winner)


func _on_child_exiting_tree(_node: Node) -> void:
	_request_reflow_hand_bar()


func _on_child_entered_tree(node: Node) -> void:
	var cui := get_card_ui_in_slot(node)
	if cui:
		call_deferred("_apply_hand_card_transform", cui)


func _on_hand_slot_child_entered(child: Node) -> void:
	if child is CardUI:
		call_deferred("_apply_hand_card_transform", child as CardUI)


## 牌离槽瞬间同步处理：拖出时压扁槽宽以便其余牌立刻靠拢；永久离槽则本帧删空槽
func _on_card_tree_exited_from_slot(slot: Control) -> void:
	if not is_instance_valid(slot) or slot.get_parent() != self:
		return
	if slot.has_meta(META_SLOT_DRAG_TEMP_EMPTY) and slot.get_meta(META_SLOT_DRAG_TEMP_EMPTY, false):
		slot.custom_minimum_size = Vector2.ZERO
		_request_reflow_hand_bar()
		return
	if slot.get_child_count() != 0:
		return
	slot.custom_minimum_size = Vector2.ZERO
	_request_reflow_hand_bar()
	if not slot.is_queued_for_deletion():
		slot.queue_free()
	_request_reflow_hand_bar()


## 打出前：先把槽宽压为 0 并 reflow，避免 reparent 与 `child_exiting_tree` 之间一帧槽仍占满宽
func shrink_slot_before_card_reparent_for_play(slot: Control) -> void:
	if not is_instance_valid(slot) or slot.get_parent() != self:
		return
	if slot.has_meta(META_SLOT_DRAG_TEMP_EMPTY):
		slot.remove_meta(META_SLOT_DRAG_TEMP_EMPTY)
	slot.custom_minimum_size = Vector2.ZERO
	_request_reflow_hand_bar()


## 打出：立刻删掉空槽并保持拖出时的收窄布局（不再等 CardUI queue_free / tree_exited）
func remove_empty_slot_after_play(slot: Control) -> void:
	if not is_instance_valid(slot) or slot.get_parent() != self:
		return
	if slot.has_meta(META_SLOT_DRAG_TEMP_EMPTY):
		slot.remove_meta(META_SLOT_DRAG_TEMP_EMPTY)
	slot.custom_minimum_size = Vector2.ZERO
	slot.visible = false
	if not slot.is_queued_for_deletion():
		slot.queue_free()
	_request_reflow_hand_bar()


func _request_reflow_hand_bar() -> void:
	if _reflow_running:
		_reflow_dirty = true
		return
	_reflow_running = true
	while is_inside_tree():
		_reflow_dirty = false
		_reflow_hand_bar()
		if not _reflow_dirty:
			break
	_reflow_running = false


func _apply_card_separation() -> void:
	if not is_inside_tree():
		return
	add_theme_constant_override("separation", card_separation)
	queue_redraw()
	update_minimum_size()


func _refresh_hand_card_scales() -> void:
	if not is_inside_tree():
		return
	for slot in get_children():
		var cui := get_card_ui_in_slot(slot)
		if cui:
			_apply_hand_card_transform(cui)


func has_card_resource(c: Card) -> bool:
	if c == null:
		return false
	for slot in get_children():
		var cui := get_card_ui_in_slot(slot)
		if cui and cui.card == c:
			return true
	return false


func add_card(card: Card) -> void:
	var owning_player := player
	if not is_instance_valid(owning_player):
		# 战斗场景里 Hand 的 @export「玩家」未连上时为 null；默认与 Battle 里布局一致
		owning_player = get_node_or_null("../../Player") as Player
	if not is_instance_valid(owning_player):
		push_error("Hand.add_card: 未设置 player，且无法从 ../../Player 解析到 Player 节点。")
		return

	var slot := Control.new()
	slot.name = "HandCardSlot"
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 避免 HBox 把槽横向/纵向拉满剩余空间，导致整张牌被撑到异常大、右侧留白
	slot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	slot.child_entered_tree.connect(_on_hand_slot_child_entered)
	add_child(slot)

	var new_card_ui := CARD_UI_SCENE.instantiate() as CardUI
	slot.add_child(new_card_ui)
	new_card_ui.hand_slot = slot
	# 打出/销毁时 CardUI 离树：用 tree_exited 比 child_exiting+await 更稳；空槽若留着会仍带 custom_minimum_size 占一条缝
	new_card_ui.tree_exited.connect(_on_card_tree_exited_from_slot.bind(slot))
	new_card_ui.position = Vector2.ZERO
	new_card_ui.reparent_requested.connect(_on_card_ui_reparent_requested)
	new_card_ui.card = card
	new_card_ui.parent = self
	new_card_ui.char_stats = char_stats
	new_card_ui.player_modifiers = owning_player.modifier_handler
	new_card_ui.refresh_combat_description()
	_apply_hand_card_transform(new_card_ui)
	call_deferred("_apply_hand_card_transform", new_card_ui)
	_request_reflow_hand_bar()


func _reflow_hand_bar() -> void:
	if not is_inside_tree():
		return
	var slots_with_card: Array[Node] = []
	for slot in get_children():
		if get_card_ui_in_slot(slot) != null:
			slots_with_card.append(slot)
	var n := slots_with_card.size()
	var bar_h := size.y
	if bar_h < 1.0:
		bar_h = roundf(CARD_UI_BASE_SIZE.y * display_scale)
	if n == 0:
		custom_minimum_size = Vector2(0.0, bar_h)
		offset_left = -_empty_bar_half_width
		offset_right = _empty_bar_half_width
		update_minimum_size()
		queue_sort()
		return
	var sep := float(card_separation)
	var total_w := 0.0
	var max_h := 0.0
	for slot in slots_with_card:
		var ctl := slot as Control
		if ctl == null:
			continue
		var ms: Vector2 = ctl.get_combined_minimum_size()
		total_w += ms.x
		max_h = maxf(max_h, ms.y)
	if n > 1:
		total_w += sep * float(n - 1)
	var half := total_w * 0.5
	offset_left = -half
	offset_right = half
	custom_minimum_size = Vector2(total_w, maxf(max_h, bar_h))
	update_minimum_size()
	queue_sort()


func get_card_ui_in_slot(slot_or_card: Node) -> CardUI:
	if slot_or_card is CardUI:
		return slot_or_card as CardUI
	for ch in slot_or_card.get_children():
		if ch is CardUI:
			return ch as CardUI
	return null


func discard_card(card: CardUI) -> void:
	var p := card.get_parent()
	if p and p != self:
		p.queue_free()
	else:
		card.queue_free()
	_request_reflow_hand_bar()


func enable_hand() -> void:
	for slot in get_children():
		var card := get_card_ui_in_slot(slot)
		if not card:
			continue
		card.disabled = false
		card.refresh_combat_description()
		card.sync_hand_hover_presentation()


func disable_hand() -> void:
	for slot in get_children():
		var card := get_card_ui_in_slot(slot)
		if not card:
			continue
		card.disabled = true
		card.force_hand_hover_visuals_off()


func _on_card_ui_reparent_requested(child: CardUI) -> void:
	child.disabled = true
	if is_instance_valid(child.hand_slot) and child.hand_slot.get_parent() == self:
		child.hand_slot.visible = true
		child.reparent(child.hand_slot)
		if child.hand_slot.has_meta(META_SLOT_DRAG_TEMP_EMPTY):
			child.hand_slot.remove_meta(META_SLOT_DRAG_TEMP_EMPTY)
		child.reset_hand_hover_lift_instant()
		var new_index := clampi(child.original_index, 0, maxi(0, get_child_count() - 1))
		move_child.call_deferred(child.hand_slot, new_index)
	else:
		if not is_instance_valid(child.hand_slot):
			return
		child.reparent(self)
		child.reset_hand_hover_lift_instant()
		var new_index_legacy := clampi(child.original_index, 0, maxi(0, get_child_count() - 1))
		move_child.call_deferred(child, new_index_legacy)
	child.set_deferred("disabled", false)
	child.refresh_combat_description()
	_apply_hand_card_transform(child)
	call_deferred("_apply_hand_card_transform", child)
	call_deferred("_sync_card_hover_after_return_to_hand", child)
	_request_reflow_hand_bar()


func _sync_card_hover_after_return_to_hand(card: CardUI) -> void:
	if is_instance_valid(card):
		card.sync_hand_hover_presentation()


func _apply_hand_card_transform(card_ui: CardUI) -> void:
	if not is_instance_valid(card_ui):
		return
	var s := display_scale
	# 必须保持为 1，否则每次 HBox 排序都会被 Container 盖回 (1,1)
	card_ui.scale = Vector2.ONE

	var scaled_size := Vector2(
		roundf(CARD_UI_BASE_SIZE.x * s),
		roundf(CARD_UI_BASE_SIZE.y * s)
	)

	# 仅当牌仍是槽的子节点时才写槽的 minimum_size。否则（拖出/打出已 reparent 但 hand_slot 尚未清空）
	# 会把 shrink_slot 压成的 0 宽又改回满宽，出现「空槽占位」闪一下。
	if is_instance_valid(card_ui.hand_slot) and card_ui.get_parent() == card_ui.hand_slot:
		card_ui.hand_slot.custom_minimum_size = scaled_size
		card_ui.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		card_ui.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		card_ui.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
		card_ui.offset_left = 0.0
		card_ui.offset_top = 0.0
		card_ui.offset_right = scaled_size.x
		card_ui.offset_bottom = scaled_size.y

	if is_equal_approx(s, 1.0):
		card_ui.custom_minimum_size = CARD_UI_BASE_SIZE
		card_ui.pivot_offset = Vector2.ZERO
		card_ui.texture_filter = CanvasItem.TEXTURE_FILTER_PARENT_NODE
	else:
		card_ui.custom_minimum_size = scaled_size
		card_ui.pivot_offset = scaled_size * 0.5
		card_ui.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_sync_drop_point_collision(card_ui, scaled_size if not is_equal_approx(s, 1.0) else CARD_UI_BASE_SIZE)


func _sync_drop_point_collision(card_ui: CardUI, hit_size: Vector2) -> void:
	var shape_node := card_ui.get_node_or_null("DropPointDetector/CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	var rect_shape: RectangleShape2D
	if shape_node.shape is RectangleShape2D:
		rect_shape = shape_node.shape as RectangleShape2D
	else:
		rect_shape = RectangleShape2D.new()
		shape_node.shape = rect_shape
	rect_shape.size = hit_size
	shape_node.position = hit_size * 0.5
