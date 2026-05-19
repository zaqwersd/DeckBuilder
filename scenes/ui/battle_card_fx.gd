class_name BattleCardFx
extends Control

## 战斗内卡牌飞行动画：抽牌、打出、弃牌、Boss 塞入抽牌堆
## 幽灵卡挂在 BattleUI（CanvasLayer）上并 top_level，避免父 Control 无尺寸时坐标全挤在一处。

const CARD_MENU_UI := preload("res://scenes/ui/card_menu_ui.tscn")

enum PlayedKind { DISCARD, EXHAUST, POWER }

## 幽灵缩放：仅从抽牌堆飞向手牌为 0→1；飞入抽牌堆/弃牌堆（及打出第二段）为 1→0
const SK_SCALE_EXPAND := 0
const SK_SCALE_SHRINK := 1

const DRAW_DURATION := 0.26
const PLAY_TO_CENTER := 0.12
const PLAY_HOLD := 0.05
const PLAY_TO_PILE := 0.24
## 能力牌：先飞到屏中（与普通打出一致），再在中心放大至最多原尺寸 1.2 倍并淡出
const POWER_POP_DURATION := 0.38
const POWER_MAX_SCALE := 1.2
const DISCARD_HAND_DURATION := 0.24
const INSERT_TO_DRAW := 0.22
## 塞牌/复制：先在屏中央从 scale 0 渐显至 1，再停留、飞入堆
const INSERT_REVEAL_DURATION := 0.34
const INSERT_CENTER_HOLD := 1.0
const GHOST_FADE_DURATION := 0.48
## 多卡并列时：卡宽 + 间隙，至少不小于此值（像素）
const MULTI_INSERT_MIN_STEP_PX := 120.0
const MULTI_INSERT_CARD_GAP_PX := 36.0
## 生死流转：消耗堆牌错开飞出、屏心变化、再入抽牌堆
const SAMSARA_STAGGER := 0.1
const SAMSARA_TO_CENTER := 0.14
const SAMSARA_TRANSFORM_POP := 0.28
const SAMSARA_OLD_FADE := 0.12
const SAMSARA_TO_DRAW := INSERT_TO_DRAW
const SAMSARA_ANCHOR_Z := 420
const SAMSARA_LANE_Z := 410
const SAMSARA_ANCHOR_HOLD := 0.02
## 单条 lane 预估时长（飞到屏心+变化+飞抽牌堆），用于并行等待兜底
const SAMSARA_LANE_PIPELINE_ESTIMATE := 0.82
const SAMSARA_PIPELINE_TIMEOUT_PAD := 1.2
var draw_pile_button: Control
var discard_pile_button: Control
var exhaust_pile_button: Control


func _ready() -> void:
	add_to_group("battle_card_fx")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fit_to_viewport()
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)


func _on_viewport_size_changed() -> void:
	_fit_to_viewport()


func _fit_to_viewport() -> void:
	var r := get_viewport().get_visible_rect()
	position = r.position
	size = r.size


func setup(draw_btn: Control, discard_btn: Control, exhaust_btn: Control = null) -> void:
	draw_pile_button = draw_btn
	discard_pile_button = discard_btn
	exhaust_pile_button = exhaust_btn


func _sync_card_to_hand_if_missing(hand: Hand, card: Card) -> void:
	if not is_instance_valid(hand) or card == null:
		return
	if hand.has_card_resource(card):
		return
	hand.add_card(card)


func animate_draw_to_hand(card: Card, hand: Hand, start_delay: float = 0.0) -> void:
	if not hand:
		return
	if Events.is_combat_ended():
		_sync_card_to_hand_if_missing(hand, card)
		return
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
	if Events.is_combat_ended():
		_sync_card_to_hand_if_missing(hand, card)
		return
	if not draw_pile_button:
		_sync_card_to_hand_if_missing(hand, card)
		return
	var ghost := _make_ghost(card)
	var from := _control_global_center(draw_pile_button)
	var to := _control_global_center(hand)
	var mid_draw := _bezier_control_draw_bulge_up(from, to)
	await _prepare_ghost_for_motion(ghost)
	if Events.is_combat_ended():
		if is_instance_valid(ghost):
			ghost.queue_free()
		_sync_card_to_hand_if_missing(hand, card)
		return
	await _tween_ghost_curve_scale(ghost, from, to, DRAW_DURATION, false, mid_draw, SK_SCALE_EXPAND)
	if Events.is_combat_ended():
		if is_instance_valid(ghost):
			ghost.queue_free()
		_sync_card_to_hand_if_missing(hand, card)
		return
	if is_instance_valid(ghost):
		ghost.queue_free()
	_sync_card_to_hand_if_missing(hand, card)


func animate_played_card(card: Card, start_center: Vector2, kind: PlayedKind) -> void:
	if Events.is_combat_ended():
		return
	var ghost := _make_ghost(card)
	if kind == PlayedKind.EXHAUST:
		ghost.modulate = Color(1.0, 0.62, 0.35)
	elif kind == PlayedKind.POWER:
		ghost.modulate = Color(0.85, 0.9, 1.0)

	await _prepare_ghost_for_motion(ghost)
	if Events.is_combat_ended():
		if is_instance_valid(ghost):
			ghost.queue_free()
		return

	if kind == PlayedKind.POWER:
		var vp_center_p := get_viewport().get_visible_rect().get_center()
		var mid1_p := _bezier_control_draw_bulge_up(start_center, vp_center_p)
		await _tween_ghost_curve_scale(ghost, start_center, vp_center_p, PLAY_TO_CENTER, false, mid1_p, SK_SCALE_EXPAND)
		await get_tree().create_timer(PLAY_HOLD).timeout
		if Events.is_combat_ended():
			if is_instance_valid(ghost):
				ghost.queue_free()
			return
		if not is_instance_valid(ghost):
			return
		var tw_power := create_tween()
		tw_power.set_parallel(true)
		tw_power.set_trans(Tween.TRANS_QUAD)
		tw_power.set_ease(Tween.EASE_OUT)
		tw_power.tween_property(ghost, "scale", Vector2.ONE * POWER_MAX_SCALE, POWER_POP_DURATION)
		tw_power.tween_property(ghost, "modulate:a", 0.0, POWER_POP_DURATION * 0.95)
		await tw_power.finished
		if Events.is_combat_ended():
			if is_instance_valid(ghost):
				ghost.queue_free()
			return
		if is_instance_valid(ghost):
			ghost.queue_free()
		return

	var vp_center := get_viewport().get_visible_rect().get_center()
	var mid1 := _bezier_control_draw_bulge_up(start_center, vp_center)
	await _tween_ghost_curve_scale(ghost, start_center, vp_center, PLAY_TO_CENTER, false, mid1, SK_SCALE_EXPAND)
	await get_tree().create_timer(PLAY_HOLD).timeout
	if Events.is_combat_ended():
		if is_instance_valid(ghost):
			ghost.queue_free()
		return

	if kind == PlayedKind.EXHAUST:
		# 打出就消耗的牌：在屏幕中央暂留然后淡出
		await get_tree().create_timer(0.5).timeout  # 0.5s暂留效果
		if Events.is_combat_ended():
			if is_instance_valid(ghost):
				ghost.queue_free()
			return
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_QUAD)
		tw.set_ease(Tween.EASE_OUT)
		tw.tween_property(ghost, "modulate:a", 0.0, PLAY_TO_PILE)
		await tw.finished
		if Events.is_combat_ended():
			if is_instance_valid(ghost):
				ghost.queue_free()
			return
		if is_instance_valid(ghost):
			ghost.queue_free()
		_notify_haunted_if_ghost(card)
		return

	if not discard_pile_button:
		if is_instance_valid(ghost):
			ghost.queue_free()
		return
	var dest := _control_global_center(discard_pile_button)
	var mid2 := _bezier_control_draw_bulge_up(vp_center, dest)
	await _tween_ghost_curve_scale(ghost, vp_center, dest, PLAY_TO_PILE, false, mid2, SK_SCALE_SHRINK)
	if Events.is_combat_ended():
		if is_instance_valid(ghost):
			ghost.queue_free()
		return
	if is_instance_valid(ghost):
		ghost.queue_free()


## 生死流转：锚点飞到屏心；消耗堆牌错开启动，每条独立完成 飞到屏心→变化→飞入抽牌堆。
func animate_samsara_transform(
	samsara_card: Card,
	pairs: Array,
	samsara_from: Vector2,
	char_stats: CharacterStats
) -> void:
	var anchor: Control = null
	if samsara_card == null or not char_stats or not _is_fx_in_tree():
		_fallback_samsara_add_draw(pairs, char_stats)
		return

	var vp_center := get_viewport().get_visible_rect().get_center()
	var exhaust_from := vp_center
	if exhaust_pile_button:
		exhaust_from = _control_global_center(exhaust_pile_button)

	anchor = _make_ghost(samsara_card)
	anchor.z_index = SAMSARA_ANCHOR_Z
	if samsara_card.exhausts:
		anchor.modulate = Color(1.0, 0.62, 0.35)
	await _prepare_ghost_for_motion(anchor)
	if Events.is_combat_ended() or not _is_fx_in_tree():
		_queue_free_if_valid(anchor)
		_fallback_samsara_add_draw(pairs, char_stats)
		return

	var mid_anchor := _bezier_control_draw_bulge_up(samsara_from, vp_center)
	await _tween_ghost_curve_scale(
		anchor, samsara_from, vp_center, SAMSARA_TO_CENTER, false, mid_anchor, SK_SCALE_EXPAND
	)
	if Events.is_combat_ended() or not _is_fx_in_tree():
		_queue_free_if_valid(anchor)
		_fallback_samsara_add_draw(pairs, char_stats)
		return

	if not await _await_fx_delay(SAMSARA_ANCHOR_HOLD):
		_queue_free_if_valid(anchor)
		_fallback_samsara_add_draw(pairs, char_stats)
		return

	if not pairs.is_empty():
		_queue_free_if_valid(anchor)
		anchor = null
		await _await_samsara_lanes_pipeline(pairs, vp_center, exhaust_from, char_stats)

	_queue_free_if_valid(anchor)


## 生死流转收尾：屏心直接淡出（消耗）或飞入弃牌堆（已升级去消耗）。
func animate_samsara_resolve(card: Card, center: Vector2, exhausts: bool) -> void:
	if card == null or Events.is_combat_ended():
		return
	if exhausts:
		await animate_exhaust_fade_at_center(card, center)
	else:
		await animate_discard_from_center(card, center)


func animate_exhaust_fade_at_center(card: Card, center: Vector2) -> void:
	if Events.is_combat_ended() or not _is_fx_in_tree():
		return
	var ghost := _make_ghost(card)
	ghost.modulate = Color(1.0, 0.62, 0.35)
	await _prepare_ghost_for_motion(ghost)
	if Events.is_combat_ended() or not is_instance_valid(ghost):
		_queue_free_if_valid(ghost)
		return
	_place_visual_center_at(ghost, center)
	ghost.scale = Vector2.ONE
	ghost.visible = true
	var tw := ghost.create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "modulate:a", 0.0, PLAY_TO_PILE)
	await _await_ghost_tween_finished(ghost, tw)
	_queue_free_if_valid(ghost)
	_notify_haunted_if_ghost(card)


func animate_discard_from_center(card: Card, center: Vector2) -> void:
	if Events.is_combat_ended() or not _is_fx_in_tree():
		return
	if not discard_pile_button:
		return
	var ghost := _make_ghost(card)
	await _prepare_ghost_for_motion(ghost)
	if Events.is_combat_ended() or not is_instance_valid(ghost):
		_queue_free_if_valid(ghost)
		return
	_place_visual_center_at(ghost, center)
	ghost.scale = Vector2.ONE
	ghost.visible = true
	var dest := _control_global_center(discard_pile_button)
	var mid := _bezier_control_draw_bulge_up(center, dest)
	await _tween_ghost_curve_scale(ghost, center, dest, PLAY_TO_PILE, false, mid, SK_SCALE_SHRINK)
	_queue_free_if_valid(ghost)


## 并行 lane：错开启动，每条独立完成 飞到屏心→变化→飞入抽牌堆。
func _await_samsara_lanes_pipeline(
	pairs: Array,
	hub_center: Vector2,
	exhaust_from: Vector2,
	char_stats: CharacterStats
) -> void:
	var lane_wait := {"started": 0, "completed": 0}
	var on_lane_done := func() -> void:
		lane_wait.completed += 1

	for i in pairs.size():
		if i > 0:
			if not await _await_fx_delay(SAMSARA_STAGGER):
				break
		if Events.is_combat_ended() or not _is_fx_in_tree():
			break
		lane_wait.started += 1
		call_deferred(
			"_samsara_lane_transform_and_fly", pairs[i], hub_center, exhaust_from, char_stats, on_lane_done
		)

	var deadline := Time.get_ticks_msec() + int(
		(SAMSARA_PIPELINE_TIMEOUT_PAD + float(pairs.size()) * (SAMSARA_STAGGER + SAMSARA_LANE_PIPELINE_ESTIMATE))
		* 1000.0
	)
	while lane_wait.completed < lane_wait.started:
		if Time.get_ticks_msec() >= deadline:
			break
		if Events.is_combat_ended() or not _is_fx_in_tree():
			break
		if not await _await_fx_process_frame():
			break

	for pair_variant in pairs:
		if pair_variant is Dictionary:
			var nc: Card = (pair_variant as Dictionary).get("new")
			if nc != null and not char_stats.draw_pile.cards.has(nc):
				char_stats.draw_pile.add_card(nc)


func _samsara_lane_transform_and_fly(
	pair: Dictionary,
	hub_center: Vector2,
	exhaust_from: Vector2,
	char_stats: CharacterStats,
	on_done: Callable
) -> void:
	var new_card: Card = pair.get("new")
	var old_card: Card = pair.get("old")
	var new_ghost: Control = null

	if new_card == null:
		on_done.call()
		return

	if Events.is_combat_ended() or not _is_fx_in_tree():
		_samsara_lane_add_to_draw(new_card, char_stats)
		on_done.call()
		return

	var old_ghost: Control = null
	if old_card != null:
		old_ghost = _make_ghost(old_card)
		old_ghost.z_index = SAMSARA_LANE_Z
		await _prepare_ghost_for_motion(old_ghost)
		if Events.is_combat_ended() or not _is_fx_in_tree():
			_queue_free_if_valid(old_ghost)
			_samsara_lane_add_to_draw(new_card, char_stats)
			on_done.call()
			return
		var mid1 := _bezier_control_draw_bulge_up(exhaust_from, hub_center)
		await _tween_ghost_curve_scale(
			old_ghost, exhaust_from, hub_center, SAMSARA_TO_CENTER, false, mid1, SK_SCALE_EXPAND
		)

	if Events.is_combat_ended() or not _is_fx_in_tree():
		_queue_free_if_valid(old_ghost)
		_samsara_lane_add_to_draw(new_card, char_stats)
		on_done.call()
		return

	if is_instance_valid(old_ghost):
		var tw_fade := old_ghost.create_tween()
		tw_fade.set_parallel(true)
		tw_fade.tween_property(old_ghost, "modulate:a", 0.0, SAMSARA_OLD_FADE)
		tw_fade.tween_property(old_ghost, "scale", Vector2.ZERO, SAMSARA_OLD_FADE)
		await _await_ghost_tween_finished(old_ghost, tw_fade, SAMSARA_OLD_FADE + 0.08)
		old_ghost.queue_free()

	if Events.is_combat_ended() or not _is_fx_in_tree():
		_samsara_lane_add_to_draw(new_card, char_stats)
		on_done.call()
		return

	new_ghost = _make_ghost(new_card)
	new_ghost.z_index = SAMSARA_LANE_Z
	await _prepare_ghost_for_motion(new_ghost)
	if Events.is_combat_ended() or not _is_fx_in_tree():
		_queue_free_if_valid(new_ghost)
		_samsara_lane_add_to_draw(new_card, char_stats)
		on_done.call()
		return
	_place_visual_center_at(new_ghost, hub_center)
	new_ghost.scale = Vector2.ZERO
	new_ghost.visible = true
	var tw_pop := new_ghost.create_tween()
	tw_pop.set_trans(Tween.TRANS_CUBIC)
	tw_pop.set_ease(Tween.EASE_OUT)
	tw_pop.tween_method(func(t: float) -> void: _insert_pop_scale(new_ghost, t), 0.0, 1.0, SAMSARA_TRANSFORM_POP)
	await _await_ghost_tween_finished(new_ghost, tw_pop, SAMSARA_TRANSFORM_POP + 0.08)

	if Events.is_combat_ended() or not _is_fx_in_tree():
		_queue_free_if_valid(new_ghost)
		_samsara_lane_add_to_draw(new_card, char_stats)
		on_done.call()
		return

	_samsara_lane_add_to_draw(new_card, char_stats)
	await _samsara_fly_ghost_to_draw_pile(new_ghost)
	on_done.call()


func _samsara_lane_add_to_draw(card: Card, char_stats: CharacterStats) -> void:
	if card == null or char_stats == null:
		return
	if not char_stats.draw_pile.cards.has(card):
		char_stats.draw_pile.add_card(card)


func _samsara_fly_ghost_to_draw_pile(ghost: Control) -> void:
	if not is_instance_valid(ghost):
		return
	if Events.is_combat_ended() or not _is_fx_in_tree() or not draw_pile_button:
		_queue_free_if_valid(ghost)
		return
	ghost.visible = true
	if ghost.scale == Vector2.ZERO:
		ghost.scale = Vector2.ONE
	var dest := _control_global_center(draw_pile_button)
	var from_c := ghost.get_global_rect().get_center()
	var mid := _bezier_control_draw_bulge_up(from_c, dest)
	await _tween_ghost_curve_scale(ghost, from_c, dest, SAMSARA_TO_DRAW, false, mid, SK_SCALE_SHRINK)
	_queue_free_if_valid(ghost)


func _fallback_samsara_add_draw(pairs: Array, char_stats: CharacterStats) -> void:
	if not char_stats:
		return
	for pair_variant in pairs:
		if pair_variant is Dictionary:
			var nc: Card = (pair_variant as Dictionary).get("new")
			if nc != null and not char_stats.draw_pile.cards.has(nc):
				char_stats.draw_pile.add_card(nc)


func _is_fx_in_tree() -> bool:
	return is_instance_valid(self) and is_inside_tree() and get_tree() != null


func _await_fx_process_frame() -> bool:
	if not _is_fx_in_tree():
		return false
	await get_tree().process_frame
	return _is_fx_in_tree()


func _await_fx_delay(seconds: float) -> bool:
	if seconds <= 0.0:
		return _is_fx_in_tree()
	if not _is_fx_in_tree():
		return false
	await get_tree().create_timer(seconds).timeout
	return _is_fx_in_tree()


func _await_ghost_tween_finished(ghost: Control, tw: Tween, max_wait_sec: float = -1.0) -> void:
	if tw == null or not is_instance_valid(ghost):
		return
	if max_wait_sec <= 0.0:
		await tw.finished
		return
	if not _is_fx_in_tree():
		return
	var deadline := Time.get_ticks_msec() + int(max_wait_sec * 1000.0)
	while tw.is_valid() and tw.is_running() and is_instance_valid(ghost):
		if Time.get_ticks_msec() >= deadline:
			return
		if Events.is_combat_ended() or not _is_fx_in_tree():
			return
		if not await _await_fx_process_frame():
			return


func _queue_free_if_valid(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()


## 故障机器遗物：复制品在屏中结算效果后以「故障消散」消失（不进消耗堆）。
func animate_defect_machine_echo(
	card: Card,
	played_targets: Array[Node],
	char_stats: CharacterStats,
	player_modifiers: ModifierHandler
) -> void:
	if Events.is_combat_ended() or card == null:
		return
	var ghost := _make_ghost(card)
	ghost.modulate = Color(0.38, 0.96, 1.0, 1.0)
	await _prepare_ghost_for_motion(ghost)
	if Events.is_combat_ended():
		if is_instance_valid(ghost):
			ghost.queue_free()
		return
	var vp_center := get_viewport().get_visible_rect().get_center()
	_place_visual_center_at(ghost, vp_center)
	ghost.scale = Vector2.ZERO
	ghost.visible = true
	var tw_in := create_tween()
	tw_in.set_trans(Tween.TRANS_BACK)
	tw_in.set_ease(Tween.EASE_OUT)
	tw_in.tween_property(ghost, "scale", Vector2.ONE, 0.2)
	await tw_in.finished
	if Events.is_combat_ended():
		if is_instance_valid(ghost):
			ghost.queue_free()
		return
	await get_tree().create_timer(0.07).timeout
	if Events.is_combat_ended():
		if is_instance_valid(ghost):
			ghost.queue_free()
		return
	var eff_targets: Array[Node] = card.get_effect_targets(played_targets)
	Events.card_played.emit(card)
	await card.replay_effects_without_payment(eff_targets, player_modifiers)
	if card.sound:
		SFXPlayer.play(card.sound)
	if Events.is_combat_ended():
		if is_instance_valid(ghost):
			ghost.queue_free()
		return
	ghost.modulate = Color(0.55, 1.0, 0.72, 1.0)
	await _tween_ghost_fade_out(ghost)
	if is_instance_valid(ghost):
		ghost.queue_free()


func animate_discard_hand_end_turn(
	card_ui: CardUI,
	start_delay: float = 0.0,
	use_from_snapshot: bool = false,
	from_center: Vector2 = Vector2.ZERO
) -> void:
	# 须在 await 前快照：PlayerHandler 在固定计时后会 hand.discard_card → CardUI 可能已 queue_free，
	# 协程从 start_delay 醒来时若再读 card_ui.card 会拿到已释放的 Resource，传入 _make_ghost 报错。
	if not is_instance_valid(card_ui):
		return
	var c := card_ui.card
	if not is_instance_valid(c):
		return
	if Events.is_combat_ended():
		return
	var from: Vector2
	if use_from_snapshot:
		from = from_center
	else:
		from = card_ui.get_global_rect().get_center()
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
	if Events.is_combat_ended():
		return
	if not is_instance_valid(self):
		return
	if not is_instance_valid(c):
		return
	if not discard_pile_button:
		if is_instance_valid(card_ui) and not card_ui.is_queued_for_deletion():
			card_ui.visible = false
		return
	if is_instance_valid(card_ui) and not card_ui.is_queued_for_deletion():
		card_ui.visible = false
	var ghost := _make_ghost(c)
	var to := _control_global_center(discard_pile_button)
	var mid := _bezier_control_draw_bulge_up(from, to)
	await _tween_ghost_curve_scale(ghost, from, to, DISCARD_HAND_DURATION, true, mid, SK_SCALE_SHRINK)
	if Events.is_combat_ended():
		if is_instance_valid(ghost):
			ghost.queue_free()
		return
	if is_instance_valid(ghost):
		ghost.queue_free()


func animate_insert_into_draw_pile(
	card: Card,
	_from_global: Vector2,
	char_stats: CharacterStats,
	insert_at: int = -1
) -> void:
	if not char_stats:
		return
	if insert_at >= 0:
		char_stats.draw_pile.insert_card_at(insert_at, card)
	else:
		char_stats.draw_pile.add_card(card)
	if Events.is_combat_ended():
		return
	if not draw_pile_button:
		return
	var ghost := _make_ghost(card)
	await _prepare_ghost_for_motion(ghost)
	if Events.is_combat_ended():
		if is_instance_valid(ghost):
			ghost.queue_free()
		return
	var vp_center := get_viewport().get_visible_rect().get_center()
	_place_visual_center_at(ghost, vp_center)
	ghost.scale = Vector2.ZERO
	ghost.visible = true
	var tw_pop := create_tween()
	tw_pop.set_trans(Tween.TRANS_CUBIC)
	tw_pop.set_ease(Tween.EASE_OUT)
	# 与 _bezier_ghost_step 相同：Tween 对 .bind(Object) 的 MethodTweener 会把 float 错喂给首参
	tw_pop.tween_method(func(t: float) -> void: _insert_pop_scale(ghost, t), 0.0, 1.0, INSERT_REVEAL_DURATION)
	await tw_pop.finished
	if Events.is_combat_ended():
		if is_instance_valid(ghost):
			ghost.queue_free()
		return
	await get_tree().create_timer(INSERT_CENTER_HOLD).timeout
	if Events.is_combat_ended():
		if is_instance_valid(ghost):
			ghost.queue_free()
		return
	var pile_btn: Control = draw_pile_button
	var dest := _control_global_center(pile_btn)
	var mid_b := _bezier_control_draw_bulge_up(vp_center, dest)
	await _tween_ghost_curve_scale(ghost, vp_center, dest, INSERT_TO_DRAW, false, mid_b, SK_SCALE_SHRINK)
	if Events.is_combat_ended():
		if is_instance_valid(ghost):
			ghost.queue_free()
		return
	if is_instance_valid(ghost):
		ghost.queue_free()


## 多张牌同时塞入：中央横向排开 → 一齐弹出 → 停留 → **一并**飞入抽牌堆
func animate_multi_insert_into_draw_pile(
	cards: Array[Card],
	_from_global: Vector2,
	char_stats: CharacterStats,
	horizontal_spacing: float = 72.0
) -> void:
	if cards.is_empty():
		return
	if not char_stats:
		return
	if not draw_pile_button:
		for c in cards:
			char_stats.draw_pile.add_card(c)
		return
	for c in cards:
		char_stats.draw_pile.add_card(c)
	if Events.is_combat_ended():
		return
	var vp_center := get_viewport().get_visible_rect().get_center()
	var ghosts: Array[Control] = await _build_multi_insert_ghosts(cards, vp_center, horizontal_spacing)
	if Events.is_combat_ended():
		for g in ghosts:
			if is_instance_valid(g):
				g.queue_free()
		return
	var tw_pop := create_tween()
	tw_pop.set_trans(Tween.TRANS_CUBIC)
	tw_pop.set_ease(Tween.EASE_OUT)
	tw_pop.set_parallel(true)
	for g in ghosts:
		var gh: Control = g
		tw_pop.tween_method(func(t: float) -> void: _insert_pop_scale(gh, t), 0.0, 1.0, INSERT_REVEAL_DURATION)
	await tw_pop.finished
	if Events.is_combat_ended():
		for g in ghosts:
			if is_instance_valid(g):
				g.queue_free()
		return
	await get_tree().create_timer(INSERT_CENTER_HOLD).timeout
	if Events.is_combat_ended():
		for g in ghosts:
			if is_instance_valid(g):
				g.queue_free()
		return
	var dest := _control_global_center(draw_pile_button)
	await _tween_multi_ghosts_fly_to_parallel(ghosts, dest, INSERT_TO_DRAW)
	if Events.is_combat_ended():
		for g in ghosts:
			if is_instance_valid(g):
				g.queue_free()
		return
	for i in ghosts.size():
		if is_instance_valid(ghosts[i]):
			ghosts[i].queue_free()


## 多张牌塞入弃牌堆（Boss 幽灵等）：与塞抽牌堆相同演出，落点改为弃牌堆按钮。
func animate_multi_insert_into_discard_pile(
	cards: Array[Card],
	_from_global: Vector2,
	char_stats: CharacterStats,
	horizontal_spacing: float = 72.0
) -> void:
	if cards.is_empty():
		return
	if not char_stats:
		return
	if not discard_pile_button:
		for c in cards:
			char_stats.discard.add_card(c)
		return
	for c in cards:
		char_stats.discard.add_card(c)
	if Events.is_combat_ended():
		return
	var vp_center := get_viewport().get_visible_rect().get_center()
	var ghosts: Array[Control] = await _build_multi_insert_ghosts(cards, vp_center, horizontal_spacing)
	if Events.is_combat_ended():
		for g in ghosts:
			if is_instance_valid(g):
				g.queue_free()
		return
	var tw_pop := create_tween()
	tw_pop.set_trans(Tween.TRANS_CUBIC)
	tw_pop.set_ease(Tween.EASE_OUT)
	tw_pop.set_parallel(true)
	for g in ghosts:
		var gh: Control = g
		tw_pop.tween_method(func(t: float) -> void: _insert_pop_scale(gh, t), 0.0, 1.0, INSERT_REVEAL_DURATION)
	await tw_pop.finished
	if Events.is_combat_ended():
		for g in ghosts:
			if is_instance_valid(g):
				g.queue_free()
		return
	await get_tree().create_timer(INSERT_CENTER_HOLD).timeout
	if Events.is_combat_ended():
		for g in ghosts:
			if is_instance_valid(g):
				g.queue_free()
		return
	var dest := _control_global_center(discard_pile_button)
	await _tween_multi_ghosts_fly_to_parallel(ghosts, dest, INSERT_TO_DRAW)
	if Events.is_combat_ended():
		for g in ghosts:
			if is_instance_valid(g):
				g.queue_free()
		return
	for i in ghosts.size():
		if is_instance_valid(ghosts[i]):
			ghosts[i].queue_free()


func _ghost_visual_width_px(ghost: Control) -> float:
	if not is_instance_valid(ghost):
		return 268.0
	var w := ghost.get_rect().size.x
	if w < 4.0:
		w = ghost.get_combined_minimum_size().x
	if w < 4.0:
		w = 268.0
	return w


func _multi_insert_row_step_px(ghosts: Array[Control], min_step: float) -> float:
	var max_w := 0.0
	for g in ghosts:
		max_w = maxf(max_w, _ghost_visual_width_px(g))
	return maxf(maxf(min_step, MULTI_INSERT_MIN_STEP_PX), max_w + MULTI_INSERT_CARD_GAP_PX)


func _layout_multi_insert_ghosts_row(ghosts: Array[Control], vp_center: Vector2, step_px: float) -> void:
	var n := ghosts.size()
	var half := (n - 1) * 0.5
	for i in n:
		var g: Control = ghosts[i]
		if not is_instance_valid(g):
			continue
		var cx := vp_center.x + (float(i) - half) * step_px
		_place_visual_center_at(g, Vector2(cx, vp_center.y))


func _build_multi_insert_ghosts(
	cards: Array[Card],
	vp_center: Vector2,
	min_step: float
) -> Array[Control]:
	var ghosts: Array[Control] = []
	for c in cards:
		var g := _make_ghost(c)
		await _prepare_ghost_for_motion(g)
		g.scale = Vector2.ZERO
		g.visible = true
		ghosts.append(g)
	var step := _multi_insert_row_step_px(ghosts, min_step)
	_layout_multi_insert_ghosts_row(ghosts, vp_center, step)
	return ghosts


func _multi_fly_bezier_callable(data: Dictionary) -> Callable:
	## tween_method 只传入一个 float；勿用 .bind(Dictionary)，否则插值会错当成首参。
	return func(te: float) -> void:
		_bezier_ghost_step(data, te)


func _tween_multi_ghosts_fly_to_parallel(ghosts: Array[Control], dest: Vector2, duration: float) -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.set_trans(Tween.TRANS_SINE)
	for g in ghosts:
		if not is_instance_valid(g):
			continue
		var from_c := g.get_global_rect().get_center()
		var mid_b := _bezier_control_draw_bulge_up(from_c, dest)
		var data := {
			"g": g,
			"p0": from_c,
			"p1": mid_b,
			"p2": dest,
			"sk": SK_SCALE_SHRINK,
		}
		_bezier_ghost_step(data, 0.0)
		tw.tween_method(_multi_fly_bezier_callable(data), 0.0, 1.0, duration)
	await tw.finished


func animate_ethereal_vanish(hand: Hand, card_ui: CardUI) -> void:
	if not is_instance_valid(card_ui) or not card_ui.card:
		return
	var c := card_ui.card
	if Events.is_combat_ended():
		_ethereal_add_exhaust_if_possible(c)
		if is_instance_valid(hand):
			hand.discard_card(card_ui)
		return
	
	# 记录 card_ui 的精确全局变换
	var card_rect := card_ui.get_global_rect()
	var card_pos := card_rect.position
	var card_size := card_rect.size
	var card_scale := card_ui.scale
	var card_rotation := card_ui.rotation
	
	# 使用透明占位，保持手牌布局不变（其他牌不会靠拢）
	card_ui.modulate.a = 0.0
	
	var ghost := _make_ghost(c)
	await _prepare_ghost_for_motion(ghost)
	if Events.is_combat_ended():
		if is_instance_valid(ghost):
			ghost.queue_free()
		if is_instance_valid(hand):
			hand.discard_card(card_ui)
		return
	
	# 精确复制原卡牌的全局位置和尺寸（其他手牌保持原位）
	ghost.global_position = card_pos
	ghost.size = card_size
	ghost.scale = card_scale
	ghost.rotation = card_rotation
	ghost.modulate = Color(0.9, 0.88, 1.0, 1.0)
	ghost.visible = true
	
	# 直接淡出（不缩小）
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "modulate:a", 0.0, GHOST_FADE_DURATION)
	await tw.finished
	if is_instance_valid(ghost):
		ghost.queue_free()
	
	_ethereal_add_exhaust_if_possible(c)
	_notify_haunted_if_ghost(c)
	
	# 动画完成后才移除卡牌，其他手牌此时才靠拢
	if is_instance_valid(hand):
		hand.discard_card(card_ui)
		# 等待两帧让布局系统处理，然后强制重新居中
		await get_tree().process_frame
		await get_tree().process_frame
		if is_instance_valid(hand) and hand.has_method("_request_reflow_hand_bar"):
			hand._request_reflow_hand_bar()


## 通用：手牌中的卡牌被消耗（用于坚毅等效果），在原位置淡出
func animate_hand_card_exhaust(hand: Hand, card_ui: CardUI) -> void:
	if not is_instance_valid(card_ui) or not card_ui.card:
		return
	var c := card_ui.card
	
	# 记录 card_ui 的精确全局变换
	var card_rect := card_ui.get_global_rect()
	var card_pos := card_rect.position
	var card_size := card_rect.size
	var card_scale := card_ui.scale
	var card_rotation := card_ui.rotation
	
	card_ui.modulate.a = 0.0
	if is_instance_valid(hand) and is_instance_valid(card_ui.hand_slot):
		hand.collapse_slot_for_exhaust_animation(card_ui.hand_slot)
	
	var ghost := _make_ghost(c)
	await _prepare_ghost_for_motion(ghost)
	if Events.is_combat_ended():
		if is_instance_valid(ghost):
			ghost.queue_free()
		if is_instance_valid(hand):
			hand.discard_card(card_ui)
		return
	
	ghost.global_position = card_pos
	ghost.size = card_size
	ghost.scale = card_scale
	ghost.rotation = card_rotation
	ghost.visible = true
	
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "modulate:a", 0.0, GHOST_FADE_DURATION)
	await tw.finished
	if is_instance_valid(ghost):
		ghost.queue_free()
	
	if is_instance_valid(hand):
		hand.discard_card(card_ui)
		hand.resync_layout_after_draw()


func _ethereal_add_exhaust_if_possible(c: Card) -> void:
	if c == null:
		return
	var pl := get_tree().get_first_node_in_group("player") as Player
	if pl and pl.stats:
		pl.stats.add_card_to_exhaust(c)


func _notify_haunted_if_ghost(card: Card) -> void:
	if card == null or card.id != "ghost":
		return
	var p := get_tree().get_first_node_in_group("player") as Player
	if p:
		HauntedStatus.notify_ghost_consumed(p)


func _insert_pop_scale(ghost: Control, s: float) -> void:
	if is_instance_valid(ghost):
		ghost.scale = Vector2.ONE * s


func _control_global_center(ctrl: Control) -> Vector2:
	if not is_instance_valid(ctrl):
		return Vector2.ZERO
	return ctrl.get_global_rect().get_center()


func _place_visual_center_at(ghost: Control, global_center: Vector2) -> void:
	var delta := global_center - ghost.get_global_rect().get_center()
	ghost.global_position += delta


func _prepare_ghost_for_motion(ghost: Control) -> void:
	if not _is_fx_in_tree():
		return
	await get_tree().process_frame
	if not is_instance_valid(ghost):
		return
	if ghost.get_rect().size.x < 4.0 or ghost.get_rect().size.y < 4.0:
		if not _is_fx_in_tree():
			return
		await get_tree().process_frame
	if not is_instance_valid(ghost):
		return
	var preserved_center := ghost.get_global_rect().get_center()
	var sz := ghost.get_rect().size
	if sz.x < 4.0 or sz.y < 4.0:
		sz = ghost.get_combined_minimum_size()
	if sz.x < 4.0 or sz.y < 4.0:
		sz = Vector2(268.0, 348.0)
	ghost.pivot_offset = sz * 0.5
	_place_visual_center_at(ghost, preserved_center)
	if ghost is CardMenuUI:
		var cmu := ghost as CardMenuUI
		if cmu.visuals:
			cmu.visuals.apply_minimum_fonts_once_then_freeze_for_phantom()


func _bezier_control(from: Vector2, to: Vector2) -> Vector2:
	var chord := to - from
	var dist := chord.length()
	if dist < 0.001:
		dist = 0.001
	var perp := Vector2(-chord.y, chord.x).normalized()
	var up := Vector2(0, -1.0)
	var bend := perp.lerp(up, 0.45).normalized()
	var bulge := clampf(dist * 0.32, 40.0, 130.0)
	return (from + to) * 0.5 + bend * bulge


func _bezier_control_draw_bulge_up(from: Vector2, to: Vector2) -> Vector2:
	var chord := to - from
	var dist := chord.length()
	if dist < 0.001:
		dist = 0.001
	var perp := Vector2(-chord.y, chord.x).normalized()
	var screen_up := Vector2(0.0, -1.0)
	if perp.dot(screen_up) < 0.0:
		perp = -perp
	var bulge := clampf(dist * 0.34, 44.0, 140.0)
	return (from + to) * 0.5 + perp * bulge


## 幽灵卡修饰预览：从场景树解析当前玩家 ModifierHandler，避免协程里持有已释放引用传入强类型参数。
func _live_player_modifier_handler() -> ModifierHandler:
	var p := get_tree().get_first_node_in_group("player")
	if p == null or not (p is Player):
		return null
	var pl := p as Player
	if not is_instance_valid(pl) or pl.is_queued_for_deletion() or not pl.is_inside_tree():
		return null
	var mh: ModifierHandler = pl.modifier_handler
	if mh == null or not is_instance_valid(mh) or mh.is_queued_for_deletion() or not mh.is_inside_tree():
		return null
	return mh


func _make_ghost(card: Card) -> CardMenuUI:
	var ghost := CARD_MENU_UI.instantiate() as CardMenuUI
	var holder: Node = get_parent()
	if holder:
		holder.add_child(ghost)
	else:
		add_child(ghost)
	ghost.top_level = true
	ghost.z_index = 400
	ghost.z_as_relative = false
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.card = card
	var mh := _live_player_modifier_handler()
	if mh != null:
		ghost.set_modifier_preview(mh, null)
	ghost.visible = false
	ghost.custom_minimum_size = Vector2(268.0, 348.0)
	return ghost


func _tween_ghost_fade_out(ghost: Control) -> void:
	if not is_instance_valid(ghost):
		return
	var dur := GHOST_FADE_DURATION
	var tw := create_tween()
	# 虚无牌：在原位置淡出（不缩小）
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "modulate:a", 0.0, dur)
	await tw.finished


func _scale_k_factor(sk: int, te: float) -> float:
	if sk == SK_SCALE_SHRINK:
		return 1.0 - te
	return te


func _bezier_ghost_step(data: Dictionary, te: float) -> void:
	var ghost := data["g"] as Control
	if not is_instance_valid(ghost):
		return
	var p0: Vector2 = data["p0"]
	var p1: Vector2 = data["p1"]
	var p2: Vector2 = data["p2"]
	var sk: int = data["sk"]
	var u := 1.0 - te
	var pos := u * u * p0 + 2.0 * u * te * p1 + te * te * p2
	var sc := _scale_k_factor(sk, te)
	ghost.scale = Vector2.ONE * sc
	var delta := pos - ghost.get_global_rect().get_center()
	ghost.global_position += delta


func _tween_ghost_curve_scale(
	ghost: Control,
	from_center: Vector2,
	to_center: Vector2,
	duration: float,
	wait_layout: bool,
	mid_override: Vector2,
	scale_sk: int
) -> void:
	if not is_instance_valid(ghost):
		return
	if wait_layout:
		await _prepare_ghost_for_motion(ghost)
		if not is_instance_valid(ghost):
			return
	var mid := mid_override
	if mid == Vector2.ZERO:
		mid = _bezier_control_draw_bulge_up(from_center, to_center)
	var data := {
		"g": ghost,
		"p0": from_center,
		"p1": mid,
		"p2": to_center,
		"sk": scale_sk,
	}
	_bezier_ghost_step(data, 0.0)
	if is_instance_valid(ghost):
		ghost.visible = true
	if not is_instance_valid(ghost):
		return
	var tw := ghost.create_tween()
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.set_trans(Tween.TRANS_SINE)
	# 勿用 .bind(data)：Tween 的 MethodTweener 会把插值 float 当作第 1 个实参直接调方法，导致「float 无法转成 Dictionary」
	tw.tween_method(func(te: float) -> void: _bezier_ghost_step(data, te), 0.0, 1.0, duration)
	await _await_ghost_tween_finished(ghost, tw, duration + 0.12)
