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
const DISCARD_HAND_DURATION := 0.24
const INSERT_TO_DRAW := 0.22
const INSERT_CENTER_HOLD := 1.0
const INSERT_POP_DURATION := 0.14
const GHOST_FADE_DURATION := 0.45

var draw_pile_button: Control
var discard_pile_button: Control


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


func setup(draw_btn: Control, discard_btn: Control) -> void:
	draw_pile_button = draw_btn
	discard_pile_button = discard_btn


func animate_draw_to_hand(card: Card, hand: Hand, modifiers: ModifierHandler, start_delay: float = 0.0) -> void:
	if not hand:
		return
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
	if not draw_pile_button:
		hand.add_card(card)
		return
	var ghost := _make_ghost(card, modifiers)
	var from := _control_global_center(draw_pile_button)
	var to := _control_global_center(hand)
	var mid_draw := _bezier_control_draw_bulge_up(from, to)
	await _prepare_ghost_for_motion(ghost)
	await _tween_ghost_curve_scale(ghost, from, to, DRAW_DURATION, false, mid_draw, SK_SCALE_EXPAND)
	ghost.queue_free()
	hand.add_card(card)


func animate_played_card(card: Card, start_center: Vector2, kind: PlayedKind, modifiers: ModifierHandler) -> void:
	var ghost := _make_ghost(card, modifiers)
	if kind == PlayedKind.EXHAUST:
		ghost.modulate = Color(1.0, 0.62, 0.35)
	elif kind == PlayedKind.POWER:
		ghost.modulate = Color(0.85, 0.9, 1.0)

	await _prepare_ghost_for_motion(ghost)
	var vp_center := get_viewport().get_visible_rect().get_center()
	var mid1 := _bezier_control_draw_bulge_up(start_center, vp_center)
	await _tween_ghost_curve_scale(ghost, start_center, vp_center, PLAY_TO_CENTER, false, mid1, SK_SCALE_EXPAND)
	await get_tree().create_timer(PLAY_HOLD).timeout

	if kind == PlayedKind.EXHAUST:
		await _tween_ghost_fade_out(ghost)
		if is_instance_valid(ghost):
			ghost.queue_free()
		return

	var dest_btn := discard_pile_button if kind != PlayedKind.POWER else draw_pile_button
	if not dest_btn:
		ghost.queue_free()
		return
	var dest := _control_global_center(dest_btn)
	var mid2 := _bezier_control_draw_bulge_up(vp_center, dest)
	await _tween_ghost_curve_scale(ghost, vp_center, dest, PLAY_TO_PILE, false, mid2, SK_SCALE_SHRINK)
	ghost.queue_free()


func animate_discard_hand_end_turn(
	card_ui: CardUI,
	modifiers: ModifierHandler,
	start_delay: float = 0.0,
	use_from_snapshot: bool = false,
	from_center: Vector2 = Vector2.ZERO
) -> void:
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
	if not is_instance_valid(card_ui):
		return
	var from: Vector2
	if use_from_snapshot:
		from = from_center
	else:
		from = card_ui.get_global_rect().get_center()
	var c := card_ui.card
	if not discard_pile_button:
		card_ui.visible = false
		return
	card_ui.visible = false
	var ghost := _make_ghost(c, modifiers)
	var to := _control_global_center(discard_pile_button)
	var mid := _bezier_control_draw_bulge_up(from, to)
	await _tween_ghost_curve_scale(ghost, from, to, DISCARD_HAND_DURATION, true, mid, SK_SCALE_SHRINK)
	ghost.queue_free()


func animate_insert_into_draw_pile(card: Card, _from_global: Vector2, char_stats: CharacterStats, modifiers: ModifierHandler) -> void:
	if not draw_pile_button or not char_stats:
		if char_stats:
			char_stats.draw_pile.add_card(card)
		return
	var ghost := _make_ghost(card, modifiers)
	await _prepare_ghost_for_motion(ghost)
	var vp_center := get_viewport().get_visible_rect().get_center()
	_place_visual_center_at(ghost, vp_center)
	ghost.scale = Vector2.ZERO
	ghost.visible = true
	var tw_pop := create_tween()
	tw_pop.set_trans(Tween.TRANS_QUAD)
	tw_pop.set_ease(Tween.EASE_OUT)
	var pop_cb: Callable = _insert_pop_scale.bind(ghost)
	tw_pop.tween_method(pop_cb, 0.0, 1.0, INSERT_POP_DURATION)
	await tw_pop.finished
	await get_tree().create_timer(INSERT_CENTER_HOLD).timeout
	var pile_btn: Control = draw_pile_button
	var dest := _control_global_center(pile_btn)
	var mid_b := _bezier_control_draw_bulge_up(vp_center, dest)
	await _tween_ghost_curve_scale(ghost, vp_center, dest, INSERT_TO_DRAW, false, mid_b, SK_SCALE_SHRINK)
	char_stats.draw_pile.add_card(card)
	if is_instance_valid(ghost):
		ghost.queue_free()


func animate_ethereal_vanish(hand: Hand, card_ui: CardUI, modifiers: ModifierHandler) -> void:
	if not is_instance_valid(card_ui) or not card_ui.card:
		return
	var c := card_ui.card
	var from := card_ui.get_global_rect().get_center()
	card_ui.visible = false
	var ghost := _make_ghost(c, modifiers)
	await _prepare_ghost_for_motion(ghost)
	_place_visual_center_at(ghost, from)
	ghost.scale = Vector2.ONE
	ghost.modulate = Color(0.9, 0.88, 1.0, 1.0)
	ghost.visible = true
	await _tween_ghost_fade_out(ghost)
	if is_instance_valid(ghost):
		ghost.queue_free()
	if is_instance_valid(hand):
		hand.discard_card(card_ui)


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


func _make_ghost(card: Card, modifiers: ModifierHandler) -> CardMenuUI:
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
	if modifiers:
		ghost.set_modifier_preview(modifiers, null)
	ghost.visible = false
	return ghost


func _tween_ghost_fade_out(ghost: Control) -> void:
	if not is_instance_valid(ghost):
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ghost, "modulate:a", 0.0, GHOST_FADE_DURATION)
	tw.tween_property(ghost, "scale", Vector2.ZERO, GHOST_FADE_DURATION)
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
