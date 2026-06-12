class_name Hand
extends Control

const CARD_UI_SCENE := preload("res://scenes/card_ui/card_ui.tscn")
## 与 `card_ui.tscn` 中 CardUI 的 `custom_minimum_size` 一致
const CARD_UI_BASE_SIZE := Vector2(210, 220)

## 方案 A：超过 5 张后逐步收紧步长（总宽仍随张数增加，但每张新增宽度递减）
const OVERLAP_GRADIENT_START_COUNT := 5
const OVERLAP_GRADIENT_FULL_COUNT := 10
const MAX_HAND_WIDTH_VIEWPORT_RATIO := 0.78
const HAND_ROW_SIDE_RESERVE_PX := 240.0
const MIN_SLOT_STEP_RATIO := 0.48

## 方案 F：≤3 张几乎无弧度；张数增多后渐显拱起与倾斜
const FAN_ARC_HEIGHT_PX := 40.0
const FAN_MAX_TILT_DEG := 7.0
const FAN_ARC_MIN_COUNT := 3
const FAN_ARC_FULL_COUNT := 8
const HAND_ROW_PICK_PADDING_PX := 28.0
const HAND_SLOT_HOVER_Z := 500

@export var player: Player
@export var char_stats: CharacterStats

## 在脚本中修改；非 @export，避免战斗场景把检查器值写进 .tscn 后永远覆盖这里。
## 注意：不要用子 Control 的 `scale` 做手牌缩放——布局由本脚本手动排槽位。
var display_scale: float = 0.7
## 由 `_reflow_hand_bar` 写入：相邻槽中心水平间距（可小于槽宽以实现重叠）
var card_separation: float = 0.0

## 卡牌拖向 ui_layer 时槽会暂时无子节点，勿当作「空槽」删除
const META_SLOT_DRAG_TEMP_EMPTY := &"_hand_slot_drag_temp_empty"
## 手牌消耗动画期间槽已塌缩，勿被 `_apply_hand_card_transform` 写回满宽
const META_SLOT_EXHAUST_COLLAPSED := &"_hand_slot_exhaust_collapsed"

## 整条手牌栏整体下移（相对场景里写的 offset_top/bottom）。在 `_ready` 应用，保证进战斗必生效。
const HAND_BAR_DROP_PX := 70.0
## 选牌层 reparent 后由脚本固定 global_position，reflow 不再写 Hand 自身 offset。
const META_PICK_OVERLAY_EXTERNAL_POS := &"_hand_pick_overlay_external_pos"
const META_SLOT_FAN_ROTATION := &"_hand_slot_fan_rotation"

## 无牌时恢复场景里原来的底边手牌条半宽（offset 对称用）
var _empty_bar_half_width: float = 337.5
## 场景里 Hand 底边 offset_bottom，扇形增高时保持底边不动、只抬高 top
var _hand_bar_offset_bottom: float = 0.0

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


func _ready() -> void:
	child_entered_tree.connect(_on_child_entered_tree)
	child_exiting_tree.connect(_on_child_exiting_tree)
	_empty_bar_half_width = absf(offset_left)
	_hand_bar_offset_bottom = offset_bottom
	offset_top += HAND_BAR_DROP_PX
	offset_bottom += HAND_BAR_DROP_PX
	_hand_bar_offset_bottom += HAND_BAR_DROP_PX
	# 底边锚点居中时：必须同步 offset 宽度 = 内容宽，否则场景固定 ±337.5 会一直占满一条宽带，牌看起来不靠拢
	_refresh_hand_card_scales()
	_request_reflow_hand_bar()
	set_process(true)
	process_priority = -128
	if not Events.player_hand_cost_context_changed.is_connected(_on_player_hand_cost_context_changed):
		Events.player_hand_cost_context_changed.connect(_on_player_hand_cost_context_changed)
	if not Events.player_combat_stat_context_changed.is_connected(_on_player_combat_stat_context_changed):
		Events.player_combat_stat_context_changed.connect(_on_player_combat_stat_context_changed)
	if not Events.card_exhausted.is_connected(_on_card_exhausted_refresh_descriptions):
		Events.card_exhausted.connect(_on_card_exhausted_refresh_descriptions)
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
		cui.playable = cui.char_stats.can_play_card(
			cui.card,
			cui.get_effective_mana_cost(),
			cui.combat_player
		)


func _on_player_combat_stat_context_changed() -> void:
	_refresh_all_hand_combat_descriptions()


func _on_card_exhausted_refresh_descriptions(_exhausted_card: Card) -> void:
	_refresh_all_hand_combat_descriptions()


func _refresh_all_hand_combat_descriptions() -> void:
	for slot in get_children():
		var cui := get_card_ui_in_slot(slot)
		if cui and cui.card:
			cui.refresh_combat_description()


func get_mouse_foremost_hand_card() -> CardUI:
	return _mouse_foremost_hand_card


func get_hand_hover_unified_global_top() -> float:
	var slot_h := roundf(CARD_UI_BASE_SIZE.y * display_scale)
	return get_global_rect().end.y - slot_h - CardUI.HAND_HOVER_LIFT_PX


func _smoothstep01(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func begin_pick_overlay_external_positioning() -> void:
	set_meta(META_PICK_OVERLAY_EXTERNAL_POS, true)


func end_pick_overlay_external_positioning() -> void:
	if has_meta(META_PICK_OVERLAY_EXTERNAL_POS):
		remove_meta(META_PICK_OVERLAY_EXTERNAL_POS)


func uses_pick_overlay_external_positioning() -> bool:
	return has_meta(META_PICK_OVERLAY_EXTERNAL_POS)


func _clear_hover_and_keyword_tooltip_for_obscured_ui() -> void:
	_mouse_foremost_hand_card = null
	if _kw_tip_card != null or not _kw_tip_ids.is_empty():
		_sync_hand_keyword_tooltip(null, PackedStringArray())
	for slot in get_children():
		var c := get_card_ui_in_slot(slot)
		if c:
			c.force_hand_hover_visuals_off()


func _is_card_eligible_for_hand_pick(c: CardUI, slot: Node) -> bool:
	if c == null or c.disabled or c.get_parent() != slot:
		return false
	var sm := c.card_state_machine
	if sm == null or sm.current_state == null:
		return false
	var st := sm.current_state.state
	return (
		st == CardState.State.BASE
		or st == CardState.State.CLICKED
		or st == CardState.State.DRAGGING
	)


func _is_mouse_in_hand_row_band(mouse_pos: Vector2) -> bool:
	var row := get_global_rect()
	var pick_top := row.position.y - HAND_ROW_PICK_PADDING_PX
	var pick_bottom := row.end.y + HAND_ROW_PICK_PADDING_PX
	return mouse_pos.y >= pick_top and mouse_pos.y <= pick_bottom


## 单体牌拖动手牌区：鼠标在此范围内时卡牌跟随，离开则锁定出牌位。
func is_mouse_in_play_drag_hand_zone(mouse_global: Vector2) -> bool:
	var row := get_global_rect()
	var pick_top := row.position.y - HAND_ROW_PICK_PADDING_PX
	var pick_bottom := row.end.y + HAND_ROW_PICK_PADDING_PX
	if mouse_global.y < pick_top or mouse_global.y > pick_bottom:
		return false
	var pick_left := row.position.x - HAND_ROW_PICK_PADDING_PX
	var pick_right := row.end.x + HAND_ROW_PICK_PADDING_PX
	return mouse_global.x >= pick_left and mouse_global.x <= pick_right


func _collect_eligible_hand_cards() -> Array[CardUI]:
	var result: Array[CardUI] = []
	for slot in get_children():
		var c := get_card_ui_in_slot(slot)
		if _is_card_eligible_for_hand_pick(c, slot):
			result.append(c)
	return result


func _pick_foremost_by_horizontal_voronoi(mouse_pos: Vector2, cards: Array[CardUI]) -> CardUI:
	if cards.is_empty():
		return null
	if cards.size() == 1:
		return cards[0]
	var entries: Array[Dictionary] = []
	for c in cards:
		var gr := c.get_hand_base_pick_global_rect()
		entries.append({"card": c, "cx": gr.get_center().x})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["cx"] as float) < (b["cx"] as float)
	)
	for i in range(entries.size()):
		var cx_i: float = entries[i]["cx"] as float
		var left_bound: float = -INF if i == 0 else (entries[i - 1]["cx"] as float + cx_i) * 0.5
		var right_bound: float = (
			INF if i == entries.size() - 1 else (cx_i + entries[i + 1]["cx"] as float) * 0.5
		)
		if mouse_pos.x >= left_bound and mouse_pos.x < right_bound:
			return entries[i]["card"] as CardUI
	return entries[entries.size() - 1]["card"] as CardUI


func _update_mouse_foremost_hand_card() -> void:
	var mp := get_global_mouse_position()
	if not _is_mouse_in_hand_row_band(mp):
		_mouse_foremost_hand_card = null
		return
	var overlapping: Array[CardUI] = []
	for c in _collect_eligible_hand_cards():
		if c.get_hand_base_pick_global_rect().has_point(mp):
			overlapping.append(c)
	if overlapping.is_empty():
		_mouse_foremost_hand_card = null
		return
	_mouse_foremost_hand_card = _pick_foremost_by_horizontal_voronoi(mp, overlapping)


func _apply_hand_hover_z_order() -> void:
	for slot in get_children():
		var c := get_card_ui_in_slot(slot)
		if c == null or not is_instance_valid(c.hand_slot):
			continue
		c.hand_slot.z_index = slot.get_index()
		if not c.is_hand_hover_visual_active():
			c.z_index = 0
	var fo := _mouse_foremost_hand_card
	if is_instance_valid(fo) and is_instance_valid(fo.hand_slot):
		fo.hand_slot.z_index = HAND_SLOT_HOVER_Z
		fo.z_index = CardUI.HAND_HOVER_Z


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
	_apply_hand_hover_z_order()
	
	# 当主卡牌改变时，重置旧卡牌的描述区 meta 状态，并强制刷新 tooltip
	var foremost_changed := prev_foremost != _mouse_foremost_hand_card
	if foremost_changed and is_instance_valid(prev_foremost):
		prev_foremost.force_hand_hover_visuals_off()
	if foremost_changed and is_instance_valid(prev_foremost) and is_instance_valid(prev_foremost.card_visuals):
		prev_foremost.card_visuals.force_description_kw_meta_reset()
	
	var fo := _mouse_foremost_hand_card
	for slot in get_children():
		var card := get_card_ui_in_slot(slot)
		if card == null:
			continue
		if card == fo:
			card.sync_hand_hover_presentation()
		elif card.is_hand_hover_visual_active():
			card.force_hand_hover_visuals_off()
		elif card.is_in_hand_combat_layout():
			card._sync_hand_area_input_pickable(false)
	
	var tip_card: CardUI = null
	var tip_ids: PackedStringArray = PackedStringArray()
	if is_instance_valid(fo) and not fo.disabled and is_instance_valid(fo.card_visuals):
		var ids := fo.card_visuals.get_keyword_tooltip_ids()
		if not ids.is_empty():
			tip_card = fo
			tip_ids = ids
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
	if slot.has_meta(META_SLOT_EXHAUST_COLLAPSED):
		slot.remove_meta(META_SLOT_EXHAUST_COLLAPSED)
	slot.custom_minimum_size = Vector2.ZERO
	slot.visible = false
	if not slot.is_queued_for_deletion():
		slot.queue_free()
	_request_reflow_hand_bar()


func _slot_participates_in_row(slot: Node) -> bool:
	if not slot is Control:
		return false
	var ctl := slot as Control
	if not ctl.visible:
		return false
	if ctl.has_meta(META_SLOT_DRAG_TEMP_EMPTY) and ctl.get_meta(META_SLOT_DRAG_TEMP_EMPTY, false):
		return false
	if ctl.has_meta(META_SLOT_EXHAUST_COLLAPSED) and ctl.get_meta(META_SLOT_EXHAUST_COLLAPSED, false):
		return false
	return get_card_ui_in_slot(slot) != null


func _slot_should_skip_width_write(slot: Control) -> bool:
	if slot.has_meta(META_SLOT_DRAG_TEMP_EMPTY) and slot.get_meta(META_SLOT_DRAG_TEMP_EMPTY, false):
		return true
	if slot.has_meta(META_SLOT_EXHAUST_COLLAPSED) and slot.get_meta(META_SLOT_EXHAUST_COLLAPSED, false):
		return true
	return false


func _collapse_slot_control(slot: Control, meta_key: StringName) -> void:
	slot.set_meta(meta_key, true)
	slot.custom_minimum_size = Vector2.ZERO
	slot.size = Vector2.ZERO
	slot.visible = false
	var cui := get_card_ui_in_slot(slot)
	if cui:
		cui.visible = false


## 选牌消耗：牌移到勾选区前立即塌缩槽宽，避免 HBox 留空缝。
func collapse_slot_for_pick(slot: Control) -> void:
	if not is_instance_valid(slot) or slot.get_parent() != self:
		return
	_collapse_slot_control(slot, META_SLOT_DRAG_TEMP_EMPTY)
	_request_reflow_hand_bar()


## 手牌消耗动画：透明占位仍留在槽内，但槽不参与 HBox 排版。
func collapse_slot_for_exhaust_animation(slot: Control) -> void:
	if not is_instance_valid(slot) or slot.get_parent() != self:
		return
	_collapse_slot_control(slot, META_SLOT_EXHAUST_COLLAPSED)
	_request_reflow_hand_bar()


## 选牌取消勾选：恢复槽参与排版。
func restore_slot_after_pick(slot: Control) -> void:
	if not is_instance_valid(slot) or slot.get_parent() != self:
		return
	if slot.has_meta(META_SLOT_DRAG_TEMP_EMPTY):
		slot.remove_meta(META_SLOT_DRAG_TEMP_EMPTY)
	slot.visible = true
	slot.size = Vector2.ZERO
	_request_reflow_hand_bar()


func get_active_row_width() -> float:
	if not is_inside_tree():
		return 0.0
	var n := 0
	for slot in get_children():
		if _slot_participates_in_row(slot):
			n += 1
	if n <= 0:
		return 0.0
	var slot_w := roundf(CARD_UI_BASE_SIZE.x * display_scale)
	return _compute_hand_row_layout(n, slot_w)["total_w"] as float


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


func _schedule_pick_overlay_hand_realign() -> void:
	if not uses_pick_overlay_external_positioning():
		return
	call_deferred("_deferred_pick_overlay_hand_realign")


func _deferred_pick_overlay_hand_realign() -> void:
	if not uses_pick_overlay_external_positioning() or not is_inside_tree():
		return
	var overlay := get_tree().get_first_node_in_group("hand_card_pick_overlay")
	if overlay is HandCardPickOverlay:
		(overlay as HandCardPickOverlay).request_hand_global_realign()


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


func add_card(card: Card, insert_index: int = -1) -> void:
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
	if insert_index >= 0:
		move_child(slot, clampi(insert_index, 0, get_child_count() - 1))

	var new_card_ui := CARD_UI_SCENE.instantiate() as CardUI
	slot.add_child(new_card_ui)
	## 关键：添加到场景树后（_ready 已调用），立即初始化 CardVisuals 位置为 0
	## 必须在 _apply_hand_card_transform 之前，确保基准位置正确
	if new_card_ui.card_visuals:
		new_card_ui.card_visuals.position.y = 0.0
	new_card_ui.hand_slot = slot
	# 打出/销毁时 CardUI 离树：用 tree_exited 比 child_exiting+await 更稳；空槽若留着会仍带 custom_minimum_size 占一条缝
	new_card_ui.tree_exited.connect(
		func() -> void: _on_card_tree_exited_from_slot(slot),
		CONNECT_ONE_SHOT
	)
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
			new_card_ui.get_effective_mana_cost(),
			new_card_ui.combat_player
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


func _get_max_hand_row_width() -> float:
	if not is_inside_tree():
		return 1280.0
	var vp_w := get_viewport().get_visible_rect().size.x
	var slot_w := roundf(CARD_UI_BASE_SIZE.x * display_scale)
	return maxf(
		vp_w * MAX_HAND_WIDTH_VIEWPORT_RATIO - HAND_ROW_SIDE_RESERVE_PX,
		slot_w * 3.0
	)


func _compute_overlap_blend_t(card_count: int) -> float:
	if card_count <= OVERLAP_GRADIENT_START_COUNT:
		return 0.0
	var span := float(OVERLAP_GRADIENT_FULL_COUNT - OVERLAP_GRADIENT_START_COUNT)
	if span <= 0.0:
		return 1.0
	var past := float(card_count - OVERLAP_GRADIENT_START_COUNT)
	return _smoothstep01(past / span)


func _compute_fan_arc_scale(card_count: int) -> float:
	if card_count <= FAN_ARC_MIN_COUNT:
		return 0.0
	var span := float(FAN_ARC_FULL_COUNT - FAN_ARC_MIN_COUNT)
	if span <= 0.0:
		return 1.0
	var past := float(card_count - FAN_ARC_MIN_COUNT)
	return _smoothstep01(past / span)


func _compute_hand_row_layout(n: int, slot_w: float) -> Dictionary:
	var slot_h := roundf(CARD_UI_BASE_SIZE.y * display_scale)
	var fan_scale := _compute_fan_arc_scale(n)
	## 行高始终按满弧预留，避免弧度变小时底边锚点 Hand 整条下移
	var row_h := slot_h + FAN_ARC_HEIGHT_PX
	if n <= 0:
		return {
			"step": 0.0,
			"total_w": 0.0,
			"row_h": row_h,
			"slot_h": slot_h,
			"fan_scale": fan_scale,
		}
	var step := slot_w
	if n > 1:
		var max_w := _get_max_hand_row_width()
		var tight_step := (max_w - slot_w) / float(n - 1)
		tight_step = clampf(tight_step, slot_w * MIN_SLOT_STEP_RATIO, slot_w)
		var blend := _compute_overlap_blend_t(n)
		step = lerpf(slot_w, tight_step, blend)
	var total_w := slot_w + (n - 1) * step if n > 1 else slot_w
	return {
		"step": step,
		"total_w": total_w,
		"row_h": row_h,
		"slot_h": slot_h,
		"fan_scale": fan_scale,
	}


func _apply_fan_row_layout(
	active_slots: Array[Node],
	slot_w: float,
	slot_h: float,
	step: float,
	fan_scale: float
) -> void:
	var n := active_slots.size()
	var max_arc := FAN_ARC_HEIGHT_PX
	var arc_lift := max_arc * fan_scale
	var max_tilt := FAN_MAX_TILT_DEG * fan_scale
	## 两侧牌底边固定在同一基准线；仅拱起高度随 fan_scale 变化，中心牌顶边位置不随弧度缩小而下移
	var side_baseline_y := 0.0
	for i in range(n):
		var slot := active_slots[i] as Control
		if slot == null:
			continue
		var norm := 0.0 if n == 1 else (float(i) / float(n - 1) - 0.5) * 2.0
		var x := float(i) * step
		var norm_sq := 1.0 - norm * norm
		var y := side_baseline_y - arc_lift * norm_sq
		slot.custom_minimum_size = Vector2(slot_w, slot_h)
		slot.size = slot.custom_minimum_size
		slot.pivot_offset = Vector2(slot_w * 0.5, slot_h)
		slot.position = Vector2(x, y)
		var fan_rot := deg_to_rad(norm * max_tilt)
		slot.rotation = fan_rot
		slot.set_meta(META_SLOT_FAN_ROTATION, fan_rot)
		slot.z_index = i


func _reflow_hand_bar() -> void:
	if not is_inside_tree():
		return
	var active_slots: Array[Node] = []
	for slot in get_children():
		var ctl := slot as Control
		if ctl == null:
			continue
		if _slot_participates_in_row(slot):
			active_slots.append(slot)
		else:
			ctl.custom_minimum_size = Vector2.ZERO
			ctl.size = Vector2.ZERO
			ctl.position = Vector2.ZERO
			ctl.rotation = 0.0
	var n := active_slots.size()
	var slot_w := roundf(CARD_UI_BASE_SIZE.x * display_scale)
	var layout := _compute_hand_row_layout(n, slot_w)
	var slot_h: float = layout["slot_h"]
	var row_h: float = layout["row_h"]
	var total_w: float = layout["total_w"]
	var fan_scale: float = layout["fan_scale"]
	card_separation = layout["step"] as float
	if n == 0:
		custom_minimum_size = Vector2(0.0, slot_h)
		offset_left = -_empty_bar_half_width
		offset_right = _empty_bar_half_width
		offset_top = _hand_bar_offset_bottom - slot_h
		update_minimum_size()
		return
	_apply_fan_row_layout(active_slots, slot_w, slot_h, card_separation, fan_scale)
	custom_minimum_size = Vector2(total_w, row_h)
	if uses_pick_overlay_external_positioning():
		size = custom_minimum_size
		update_minimum_size()
		_schedule_pick_overlay_hand_realign()
		return
	var half := total_w * 0.5
	offset_left = -half
	offset_right = half
	offset_top = _hand_bar_offset_bottom - row_h
	update_minimum_size()
	_sync_hand_pick_collisions_after_reflow()


## 回合末弃牌后：移除空槽并重新扇形排布（保留牌应与「仅剩这些牌」时相同，居中）。
func finalize_end_turn_hand_layout() -> void:
	_prune_orphan_hand_slots()
	resync_layout_after_draw()


func _prune_orphan_hand_slots() -> void:
	var to_free: Array[Node] = []
	for slot in get_children():
		if _slot_participates_in_row(slot):
			continue
		if get_card_ui_in_slot(slot) != null:
			continue
		to_free.append(slot)
	for slot in to_free:
		if is_instance_valid(slot) and not slot.is_queued_for_deletion():
			slot.queue_free()


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
	if is_instance_valid(card.hand_slot):
		if card.hand_slot.has_meta(META_SLOT_EXHAUST_COLLAPSED):
			card.hand_slot.remove_meta(META_SLOT_EXHAUST_COLLAPSED)
		if card.hand_slot.has_meta(META_SLOT_DRAG_TEMP_EMPTY):
			card.hand_slot.remove_meta(META_SLOT_DRAG_TEMP_EMPTY)
	var p := card.get_parent()
	if p and p != self:
		p.queue_free()
	else:
		card.queue_free()
	_request_reflow_hand_bar()


func _gui_input(event: InputEvent) -> void:
	if Events.is_pointer_ui_obscured_for(self):
		return
	if not _hand_input_enabled or uses_pick_overlay_external_positioning():
		return
	var fo := _mouse_foremost_hand_card
	if fo == null or fo.disabled or fo.has_meta(CardUI.HAND_PICK_DELEGATE_META):
		return
	if not fo.get_hand_active_pick_global_rect().has_point(get_global_mouse_position()):
		return
	fo.forward_hand_gui_input(event)
	accept_event()


func _sync_hand_pick_collisions_after_reflow() -> void:
	for slot in get_children():
		var cui := get_card_ui_in_slot(slot)
		if cui and cui.is_in_hand_combat_layout():
			cui.sync_hand_interaction_collision_from_layout()


func enable_hand() -> void:
	_hand_input_enabled = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	for slot in get_children():
		var card := get_card_ui_in_slot(slot)
		if not card:
			continue
		card.disabled = false
		card.refresh_combat_description()
		if card.is_in_hand_combat_layout():
			card._sync_hand_area_input_pickable(false)


func disable_hand() -> void:
	_hand_input_enabled = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	if is_instance_valid(card_ui.hand_slot) and _slot_should_skip_width_write(card_ui.hand_slot):
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

	card_ui.sync_hand_interaction_collision_from_layout(
		scaled_size if not is_equal_approx(s, 1.0) else CARD_UI_BASE_SIZE
	)
