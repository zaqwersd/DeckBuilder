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
## 本帧末统一再算槽尺寸/reflow（晚于各 `call_deferred("_apply_hand_card_transform")`），避免新牌与其它手牌差一帧竖直错位。
var _hand_layout_resync_pending: bool = false
## 与 `enable_hand` / `disable_hand` 同步：玩家回合可操作时，中途 `add_card` 的新卡也应可点。
var _hand_input_enabled: bool = false

## 手牌词条 tooltip：仅当鼠标与「当前这张牌」重合时显示，由本节点统一发 Events，避免每帧重复 emit
var _kw_tip_card: CardUI = null
var _kw_tip_ids: PackedStringArray = PackedStringArray()

## 标记是否需要强制刷新 tooltip（用于相邻卡牌切换或词条链接悬停）
var _force_tooltip_refresh: bool = false

## 本帧鼠标下手牌「主目标」：扩展命中区重叠的牌中取距牌心最近者（不依赖 gui_get_hovered_control / z 同步顺序）。
var _mouse_foremost_hand_card: CardUI = null
## 滞后阈值：只有当新牌比当前牌近这么多像素时才切换，避免鼠标轻微移动导致频繁切换
const FOREMOST_SWITCH_THRESHOLD_PX := 24.0


func _enter_tree() -> void:
	_apply_card_separation()


func _ready() -> void:
	child_entered_tree.connect(_on_child_entered_tree)
	child_exiting_tree.connect(_on_child_exiting_tree)
	_empty_bar_half_width = absf(offset_left)
	# 底边锚点居中时：必须同步 offset 宽度 = 内容宽，否则场景固定 ±337.5 会一直占满一条宽带，牌看起来不靠拢
	## 副轴贴底对齐：卡牌基准位置应该一致，只通过 CardVisuals.position.y 控制抬起
	alignment = BoxContainer.ALIGNMENT_END
	_apply_card_separation()
	_refresh_hand_card_scales()
	_request_reflow_hand_bar()
	set_process(true)
	process_priority = -128
	if not Events.player_hand_cost_context_changed.is_connected(_on_player_hand_cost_context_changed):
		Events.player_hand_cost_context_changed.connect(_on_player_hand_cost_context_changed)
	# 连接词条链接刷新请求信号
	if not Events.card_keyword_tooltip_refresh_requested.is_connected(_on_tooltip_refresh_requested):
		Events.card_keyword_tooltip_refresh_requested.connect(_on_tooltip_refresh_requested)


## 处理词条链接悬停刷新请求
## 当鼠标悬停在词条链接上时，只设置标志，由 _process 统一显示
func _on_tooltip_refresh_requested(_from_visuals: Control) -> void:
	# 只标记需要刷新，让 _process 在下一帧处理
	# 不直接修改 _kw_tip_card，避免干扰 _process 的 card_changed 检测
	_force_tooltip_refresh = true


func _on_player_hand_cost_context_changed() -> void:
	for slot in get_children():
		var cui := get_card_ui_in_slot(slot)
		if not cui or not cui.char_stats or not cui.card:
			continue
		cui.refresh_mana_cost_display()
		cui.playable = cui.char_stats.can_play_card(cui.card, cui.get_effective_mana_cost())


func get_mouse_foremost_hand_card() -> CardUI:
	return _mouse_foremost_hand_card


func _clear_hover_and_keyword_tooltip_for_obscured_ui() -> void:
	_mouse_foremost_hand_card = null
	if _kw_tip_card != null or not _kw_tip_ids.is_empty():
		_sync_hand_keyword_tooltip(null, PackedStringArray())
	for slot in get_children():
		var c := get_card_ui_in_slot(slot)
		if c:
			c.force_hand_hover_visuals_off()


func _update_mouse_foremost_hand_card() -> void:
	var mp := get_global_mouse_position()
	var best: CardUI = null
	var best_d2 := INF
	var best_si := 999999
	
	## 收集所有候选卡牌（命中区重叠且状态正确）
	var candidates: Array[Dictionary] = []
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
		candidates.append({"card": c, "dist_sq": d2, "slot_idx": si})
		if d2 < best_d2 - 0.01:
			best_d2 = d2
			best_si = si
		elif is_equal_approx(d2, best_d2) and si < best_si:
			best_si = si
	
	if candidates.is_empty():
		_mouse_foremost_hand_card = null
		return
	
	## 滞后机制：如果当前牌仍然有效，只有当新牌明显更近时才切换
	if is_instance_valid(_mouse_foremost_hand_card) and not _mouse_foremost_hand_card.disabled:
		var current_still_hoverable := false
		var current_d2: float = INF
		for cand in candidates:
			if cand["card"] == _mouse_foremost_hand_card:
				current_still_hoverable = true
				current_d2 = cand["dist_sq"]
				break
		
		if current_still_hoverable:
			## 检查是否有新牌比当前牌近超过阈值（24像素）
			var threshold_sq := FOREMOST_SWITCH_THRESHOLD_PX * FOREMOST_SWITCH_THRESHOLD_PX
			var should_switch := false
			for cand in candidates:
				if cand["card"] != _mouse_foremost_hand_card:
					if cand["dist_sq"] < current_d2 - threshold_sq:
						should_switch = true
						best = cand["card"]
						break
			
			if not should_switch:
				return  ## 保持当前牌不变，避免鼠标轻微移动导致频繁切换
	
	## 选择距离最近的牌
	if best == null:
		best_d2 = INF
		for cand in candidates:
			if cand["dist_sq"] < best_d2:
				best_d2 = cand["dist_sq"]
				best = cand["card"]
	
	_mouse_foremost_hand_card = best


func _exit_tree() -> void:
	if _kw_tip_card != null:
		_kw_tip_card = null
		_kw_tip_ids = PackedStringArray()
		Events.card_keyword_tooltip_hide.emit()


func _process(_delta: float) -> void:
	if Events.is_pointer_ui_obscured_for(self):
		_clear_hover_and_keyword_tooltip_for_obscured_ui()
		return
	
	var prev_foremost := _mouse_foremost_hand_card
	var prev_tip_card := _kw_tip_card
	_update_mouse_foremost_hand_card()
	
	# 当主卡牌改变时，重置旧卡牌的描述区 meta 状态，并强制刷新 tooltip
	var foremost_changed := prev_foremost != _mouse_foremost_hand_card
	if foremost_changed and is_instance_valid(prev_foremost) and is_instance_valid(prev_foremost.card_visuals):
		prev_foremost.card_visuals.force_description_kw_meta_reset()
	
	# 收集命中区内、且带词条 tooltip 的卡牌
	var hovered_cards: Array[CardUI] = []
	for slot in get_children():
		var card := get_card_ui_in_slot(slot)
		if not card:
			continue
		card.sync_hand_hover_presentation()
		if card.is_hand_hover_hit_overlapping() and not card.disabled:
			if is_instance_valid(card.card_visuals):
				var ids := card.card_visuals.get_keyword_tooltip_ids()
				if not ids.is_empty():
					hovered_cards.append(card)
	
	var tip_card := _pick_tooltip_anchor_card(hovered_cards)
	var tip_ids: PackedStringArray = PackedStringArray()
	if tip_card != null and is_instance_valid(tip_card.card_visuals):
		tip_ids = tip_card.card_visuals.get_keyword_tooltip_ids()
	
	# 仅当将展示手牌词条 tooltip 时关闭状态 tooltip，避免手牌扩展命中区误杀状态栏悬停
	if tip_card != null:
		Events.status_tooltip_hover_hide.emit()
	
	var card_changed := tip_card != prev_tip_card
	if tip_card != null:
		if card_changed or _force_tooltip_refresh:
			_sync_hand_keyword_tooltip_force(tip_card, tip_ids)
			_force_tooltip_refresh = false
		else:
			_sync_hand_keyword_tooltip(tip_card, tip_ids)
	else:
		_sync_hand_keyword_tooltip(null, PackedStringArray())
		_force_tooltip_refresh = false


func _pick_tooltip_anchor_card(cards: Array[CardUI]) -> CardUI:
	if cards.is_empty():
		return null
	if is_instance_valid(_mouse_foremost_hand_card):
		for c in cards:
			if c == _mouse_foremost_hand_card:
				return c
	return _pick_instant_foremost_hand_card(cards)


func _pick_instant_foremost_hand_card(cards: Array[CardUI]) -> CardUI:
	if cards.is_empty():
		return null
	var mouse_pos := get_global_mouse_position()
	var best: CardUI = null
	var best_d2 := INF
	var best_slot := 999999
	for c in cards:
		if not is_instance_valid(c):
			continue
		var d2 := c.get_hand_hover_hit_global_rect().get_center().distance_squared_to(mouse_pos)
		var slot_idx := 999999
		if is_instance_valid(c.hand_slot):
			slot_idx = c.hand_slot.get_index()
		if d2 < best_d2 - 0.01:
			best_d2 = d2
			best_slot = slot_idx
			best = c
		elif is_equal_approx(d2, best_d2) and slot_idx < best_slot:
			best_slot = slot_idx
			best = c
	return best


func _kw_tip_ids_equal(a: PackedStringArray, b: PackedStringArray) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if a[i] != b[i]:
			return false
	return true


func _sync_hand_keyword_tooltip(winner: CardUI, ids: PackedStringArray) -> void:
	# 即使 ids 相同，如果卡牌不同也要更新（相邻卡牌切换）
	var same_card := winner == _kw_tip_card
	var same_ids := _kw_tip_ids_equal(ids, _kw_tip_ids)
	if same_card and same_ids:
		if (
			winner != null
			and not Events.card_keyword_tooltip_visible
			and not Events.card_keyword_tooltip_render_pending
		):
			_sync_hand_keyword_tooltip_force(winner, ids)
		return
	_kw_tip_card = winner
	_kw_tip_ids = ids.duplicate() if winner != null else PackedStringArray()
	if winner == null:
		Events.card_keyword_tooltip_hide.emit()
	else:
		Events.card_keyword_tooltip_show.emit(ids, winner)


## 强制刷新 tooltip（不检查是否与当前状态相同）
func _sync_hand_keyword_tooltip_force(winner: CardUI, ids: PackedStringArray) -> void:
	_kw_tip_card = winner
	_kw_tip_ids = ids.duplicate() if winner != null else PackedStringArray()
	if winner == null:
		Events.card_keyword_tooltip_hide.emit()
	else:
		Events.card_keyword_tooltip_show.emit(ids, winner)


func _on_child_exiting_tree(_node: Node) -> void:
	_request_reflow_hand_bar()


func _on_child_entered_tree(_node: Node) -> void:
	## 不再自动应用变换，由 add_card 和 _on_card_ui_reparent_requested 统一管理
	## 避免重复调用导致的布局竞争
	pass


func _on_hand_slot_child_entered(_child: Node) -> void:
	## 不再自动应用变换，由 add_card 统一管理
	## 避免与 add_card 中的立即调用冲突
	pass


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
	## 副轴贴底：卡牌基准位置应该一致，悬停抬起由 CardUI 内部处理
	slot.size_flags_vertical = Control.SIZE_SHRINK_END
	## 关键：立即设置槽的高度，确保与已有槽一致，避免首帧高度不同导致位置偏移
	var uniform_slot_h := roundf(CARD_UI_BASE_SIZE.y * display_scale)
	slot.custom_minimum_size = Vector2(0, uniform_slot_h)
	slot.child_entered_tree.connect(_on_hand_slot_child_entered)
	add_child(slot)

	var new_card_ui := CARD_UI_SCENE.instantiate() as CardUI
	slot.add_child(new_card_ui)
	## 关键：添加到场景树后（_ready 已调用），立即初始化 CardVisuals 位置为 0
	## 必须在 _apply_hand_card_transform 之前，确保基准位置正确
	if new_card_ui.card_visuals:
		new_card_ui.card_visuals.position.y = 0.0
	new_card_ui.hand_slot = slot
	# 打出/销毁时 CardUI 离树：用 tree_exited 比 child_exiting+await 更稳；空槽若留着会仍带 custom_minimum_size 占一条缝
	new_card_ui.tree_exited.connect(_on_card_tree_exited_from_slot.bind(slot))
	new_card_ui.reparent_requested.connect(_on_card_ui_reparent_requested)
	new_card_ui.parent = self
	new_card_ui.char_stats = char_stats
	new_card_ui.combat_player = owning_player
	new_card_ui.card = card
	new_card_ui.player_modifiers = owning_player.modifier_handler
	if _hand_input_enabled:
		new_card_ui.disabled = false
	if new_card_ui.char_stats and new_card_ui.card:
		new_card_ui.playable = new_card_ui.char_stats.can_play_card(
			new_card_ui.card,
			new_card_ui.get_effective_mana_cost()
		)
	new_card_ui.refresh_combat_description()
	new_card_ui.reset_hand_hover_lift_instant()
	## 关键：立即应用变换确保首帧位置正确，同时 deferred 确保布局稳定后再次应用
	_apply_hand_card_transform(new_card_ui)
	if _hand_input_enabled:
		new_card_ui.sync_hand_hover_presentation()
	call_deferred("_apply_hand_card_transform_and_sync", new_card_ui)
	_request_reflow_hand_bar()
	_schedule_deferred_hand_layout_resync()


func _schedule_deferred_hand_layout_resync() -> void:
	if _hand_layout_resync_pending:
		return
	_hand_layout_resync_pending = true
	call_deferred("_deferred_flush_hand_layout_resync")


func _deferred_flush_hand_layout_resync() -> void:
	_hand_layout_resync_pending = false
	resync_layout_after_draw()


func _reflow_hand_bar() -> void:
	if not is_inside_tree():
		return
	var slots_with_card: Array[Node] = []
	for slot in get_children():
		if get_card_ui_in_slot(slot) != null:
			slots_with_card.append(slot)
	var n := slots_with_card.size()
	## 统一槽高度：所有槽使用相同的固定高度，避免新槽与旧槽高度不一致
	var uniform_slot_h := roundf(CARD_UI_BASE_SIZE.y * display_scale)
	if n == 0:
		custom_minimum_size = Vector2(0.0, uniform_slot_h)
		offset_left = -_empty_bar_half_width
		offset_right = _empty_bar_half_width
		update_minimum_size()
		queue_sort()
		return
	var sep := float(card_separation)
	var total_w := 0.0
	for slot in slots_with_card:
		var ctl := slot as Control
		if ctl == null:
			continue
		var ms: Vector2 = ctl.get_combined_minimum_size()
		total_w += ms.x
		## 统一设置所有槽的高度，确保对齐一致
		ctl.custom_minimum_size = Vector2(ms.x, uniform_slot_h)
	if n > 1:
		total_w += sep * float(n - 1)
	var half := total_w * 0.5
	offset_left = -half
	offset_right = half
	## Hand 高度按统一槽高度设置
	custom_minimum_size = Vector2(total_w, uniform_slot_h)
	update_minimum_size()
	queue_sort()


## 抽牌飞入与 `add_card` 内 deferred 变换跑完后，再统一算槽尺寸与 reflow，避免新槽与其它手牌差一帧竖直基准。
func resync_layout_after_draw() -> void:
	for slot in get_children():
		var cui := get_card_ui_in_slot(slot)
		if cui:
			_apply_hand_card_transform(cui)
	_request_reflow_hand_bar()


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
	_hand_input_enabled = true
	for slot in get_children():
		var card := get_card_ui_in_slot(slot)
		if not card:
			continue
		card.disabled = false
		card.refresh_combat_description()
		card.sync_hand_hover_presentation()


func disable_hand() -> void:
	_hand_input_enabled = false
	for slot in get_children():
		var card := get_card_ui_in_slot(slot)
		if not card:
			continue
		card.disabled = true
		card.force_hand_hover_visuals_off()


## 自选层等将 CardUI 挂回槽后调用：与拖拽回手同一套 deferred 对齐与 reflow。
func sync_card_ui_after_reparent_to_slot(card_ui: CardUI) -> void:
	if not is_instance_valid(card_ui):
		return
	var p := card_ui.get_parent()
	if p == null or not is_instance_valid(p):
		return
	if p.get_parent() != self and p != self:
		return
	call_deferred("_deferred_sync_card_after_external_reparent", card_ui)


func _deferred_sync_card_after_external_reparent(card_ui: CardUI) -> void:
	if not is_instance_valid(card_ui):
		return
	_apply_hand_card_transform_and_sync(card_ui)
	_request_reflow_hand_bar()
	_schedule_deferred_hand_layout_resync()


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
	## 统一使用单次 deferred 调用，避免布局竞争
	call_deferred("_apply_hand_card_transform_and_sync", child)
	_request_reflow_hand_bar()
	_schedule_deferred_hand_layout_resync()


## 统一的 deferred 变换应用，避免多次调用导致的布局竞争
func _apply_hand_card_transform_and_sync(card_ui: CardUI) -> void:
	if not is_instance_valid(card_ui):
		return
	_apply_hand_card_transform(card_ui)
	if _hand_input_enabled:
		card_ui.sync_hand_hover_presentation()


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
		## 使用统一的槽高度，与 _reflow_hand_bar 保持一致
		var uniform_slot_h := roundf(CARD_UI_BASE_SIZE.y * display_scale)
		card_ui.hand_slot.custom_minimum_size = Vector2(scaled_size.x, uniform_slot_h)
		card_ui.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		## CardUI 在 slot 内贴底对齐，确保基准位置一致
		card_ui.size_flags_vertical = Control.SIZE_SHRINK_END
		## 使用 PRESET_TOP_LEFT 确保 CardUI 在手牌槽内固定位置
		card_ui.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
		## CardUI 的 offset 只管理基础位置和尺寸，使用统一高度
		card_ui.offset_left = 0.0
		card_ui.offset_top = 0.0
		card_ui.offset_right = scaled_size.x
		card_ui.offset_bottom = uniform_slot_h

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
