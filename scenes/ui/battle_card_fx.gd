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
		var dest_ex: Vector2
		if exhaust_pile_button:
			dest_ex = _control_global_center(exhaust_pile_button)
		else:
			dest_ex = vp_center
		var mid_ex := _bezier_control_draw_bulge_up(vp_center, dest_ex)
		await _tween_ghost_curve_scale(ghost, vp_center, dest_ex, PLAY_TO_PILE, false, mid_ex, SK_SCALE_SHRINK)
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
	card.apply_effects(eff_targets, player_modifiers)
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


func animate_insert_into_draw_pile(card: Card, _from_global: Vector2, char_stats: CharacterStats) -> void:
	if not char_stats:
		return
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
	var from := card_ui.get_global_rect().get_center()
	card_ui.visible = false
	var ghost := _make_ghost(c)
	await _prepare_ghost_for_motion(ghost)
	if Events.is_combat_ended():
		if is_instance_valid(ghost):
			ghost.queue_free()
		_ethereal_add_exhaust_if_possible(c)
		if is_instance_valid(hand):
			hand.discard_card(card_ui)
		return
	_place_visual_center_at(ghost, from)
	ghost.scale = Vector2.ONE
	ghost.modulate = Color(0.9, 0.88, 1.0, 1.0)
	ghost.visible = true
	await _tween_ghost_fade_out(ghost)
	if Events.is_combat_ended():
		if is_instance_valid(ghost):
			ghost.queue_free()
		_ethereal_add_exhaust_if_possible(c)
		if is_instance_valid(hand):
			hand.discard_card(card_ui)
		return
	if is_instance_valid(ghost):
		ghost.queue_free()
	_ethereal_add_exhaust_if_possible(c)
	_notify_haunted_if_ghost(c)
	if is_instance_valid(hand):
		hand.discard_card(card_ui)


func _ethereal_add_exhaust_if_possible(c: Card) -> void:
	if c == null:
		return
	var pl := get_tree().get_first_node_in_group("player") as Player
	if pl and pl.stats and pl.stats.exhaust:
		pl.stats.exhaust.add_card(c)


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
	await get_tree().process_frame
	if not is_instance_valid(ghost):
		return
	if ghost.get_rect().size.x < 4.0 or ghost.get_rect().size.y < 4.0:
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
	return ghost


func _tween_ghost_fade_out(ghost: Control) -> void:
	if not is_instance_valid(ghost):
		return
	var dur := GHOST_FADE_DURATION
	var tw := create_tween()
	# 先明显缩小再淡出，避免与 modulate 并行时肉眼只看到「变透明」
	tw.tween_property(ghost, "scale", Vector2.ZERO, dur * 0.58).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_property(ghost, "modulate:a", 0.0, dur * 0.42)
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
	if wait_layout:
		await _prepare_ghost_for_motion(ghost)
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
	var tw := create_tween()
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.set_trans(Tween.TRANS_SINE)
	# 勿用 .bind(data)：Tween 的 MethodTweener 会把插值 float 当作第 1 个实参直接调方法，导致「float 无法转成 Dictionary」
	tw.tween_method(func(te: float) -> void: _bezier_ghost_step(data, te), 0.0, 1.0, duration)
	await tw.finished
