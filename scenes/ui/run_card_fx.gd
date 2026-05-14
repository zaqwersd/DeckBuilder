class_name RunCardFx
extends Control

## 地图界面：新卡飞入牌库按钮（奖励 / 商店）
## 飞入牌库：沿上凸贝塞尔，缩放 1→0（与战斗内飞入堆一致）

const CARD_MENU_UI := preload("res://scenes/ui/card_menu_ui.tscn")

var deck_button: Control

const FLY_DURATION := 0.34
## 仅当 from_global == ZERO（凭空出现在屏中）时先停留再飞入；商店/奖励从控件位置飞出则不停留
const CENTER_HOLD_BEFORE_DECK_FLY := 1.0
## 中央显现：复制/凭空入库先 0→1 再停留、飞入（时长为原先一半 ≈ 2 倍速度）
const CENTER_REVEAL_DURATION := 0.17
const SPIRAL_TURNS := 2.25
## 飞入牌库全程仅旋转一整圈
const FLY_ROTATIONS := 1.0


func _ready() -> void:
	add_to_group("run_card_fx")
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


func setup(deck_btn: Control) -> void:
	deck_button = deck_btn


func _deferred_animate_card_to_deck(card: Card, from_global: Vector2) -> void:
	await animate_card_to_deck(card, from_global)


func _deferred_animate_picked_to_deck(picked: CardMenuUI, from_global: Vector2) -> void:
	await animate_picked_menu_to_deck(picked, from_global)


const SHRINK_REMOVE_DURATION := 0.38
const TWO_CARD_REMOVE_DURATION := 0.38
const TWO_CARD_HORIZONTAL_GAP := 80.0  # 两张牌之间的水平间距（靠近一点）
const TWO_CARD_HOLD_DURATION := 0.5  # 两张牌暂留时间


func animate_card_center_shrink_remove(card: Card) -> void:
	if not card:
		return
	var ghost := CARD_MENU_UI.instantiate() as CardMenuUI
	var layer := get_parent()
	if layer:
		layer.add_child(ghost)
	else:
		add_child(ghost)
	ghost.top_level = true
	ghost.z_index = 200
	ghost.z_as_relative = false
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.card = card
	if ghost.visuals:
		ghost.visuals.freeze_font_sync_for_fly_phantom = true
	ghost.visible = false
	await _prepare_card_menu_pivot(ghost)
	if not is_instance_valid(ghost):
		return
	var vp_center := get_viewport().get_visible_rect().get_center()
	_place_visual_center_at(ghost, vp_center)
	ghost.rotation = 0.0
	ghost.scale = Vector2.ONE
	ghost.visible = true
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_IN)
	tw.tween_property(ghost, "scale", Vector2.ZERO, SHRINK_REMOVE_DURATION)
	await tw.finished
	if is_instance_valid(ghost):
		ghost.queue_free()


func animate_two_cards_center_fade_remove(card1: Card, card2: Card) -> void:
	if not card1 or not card2:
		return
	
	# 创建两个 ghost 卡牌
	var ghost1 := CARD_MENU_UI.instantiate() as CardMenuUI
	var ghost2 := CARD_MENU_UI.instantiate() as CardMenuUI
	
	var layer := get_parent()
	if layer:
		layer.add_child(ghost1)
		layer.add_child(ghost2)
	else:
		add_child(ghost1)
		add_child(ghost2)
	
	# 设置 ghost1
	ghost1.top_level = true
	ghost1.z_index = 200
	ghost1.z_as_relative = false
	ghost1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost1.card = card1
	if ghost1.visuals:
		ghost1.visuals.freeze_font_sync_for_fly_phantom = true
	ghost1.visible = false
	
	# 设置 ghost2
	ghost2.top_level = true
	ghost2.z_index = 200
	ghost2.z_as_relative = false
	ghost2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost2.card = card2
	if ghost2.visuals:
		ghost2.visuals.freeze_font_sync_for_fly_phantom = true
	ghost2.visible = false
	
	# 等待准备完成
	await _prepare_card_menu_pivot(ghost1)
	await _prepare_card_menu_pivot(ghost2)
	
	if not is_instance_valid(ghost1) or not is_instance_valid(ghost2):
		if is_instance_valid(ghost1):
			ghost1.queue_free()
		if is_instance_valid(ghost2):
			ghost2.queue_free()
		return
	
	# 计算位置：屏幕中央，两张牌水平排列
	var vp_center := get_viewport().get_visible_rect().get_center()
	var card_width := 268.0  # CardMenuUI 默认宽度
	var gap := TWO_CARD_HORIZONTAL_GAP
	var total_width := card_width * 2 + gap
	
	var left_pos := vp_center - Vector2(total_width * 0.5 - card_width * 0.5, 0)
	var right_pos := vp_center + Vector2(total_width * 0.5 - card_width * 0.5, 0)
	
	# 放置卡牌
	_place_visual_center_at(ghost1, left_pos)
	_place_visual_center_at(ghost2, right_pos)
	
	ghost1.rotation = 0.0
	ghost1.scale = Vector2.ONE
	ghost1.visible = true
	
	ghost2.rotation = 0.0
	ghost2.scale = Vector2.ONE
	ghost2.visible = true
	
	# 暂留效果
	await get_tree().create_timer(TWO_CARD_HOLD_DURATION).timeout
	
	# 同时执行淡出动画
	var tw1 := create_tween()
	tw1.set_trans(Tween.TRANS_QUAD)
	tw1.set_ease(Tween.EASE_OUT)
	tw1.tween_property(ghost1, "modulate:a", 0.0, TWO_CARD_REMOVE_DURATION)
	
	var tw2 := create_tween()
	tw2.set_trans(Tween.TRANS_QUAD)
	tw2.set_ease(Tween.EASE_OUT)
	tw2.tween_property(ghost2, "modulate:a", 0.0, TWO_CARD_REMOVE_DURATION)
	
	# 等待两个动画都完成
	await tw1.finished
	await tw2.finished
	
	# 清理
	if is_instance_valid(ghost1):
		ghost1.queue_free()
	if is_instance_valid(ghost2):
		ghost2.queue_free()


func animate_picked_menu_to_deck(picked: CardMenuUI, from_global: Vector2) -> void:
	if not deck_button or not is_instance_valid(picked) or not picked.card:
		if is_instance_valid(picked):
			picked.queue_free()
		return
	var layer := get_parent()
	if layer and picked.get_parent() != layer:
		layer.add_child(picked)
	picked.top_level = true
	picked.z_index = 200
	picked.z_as_relative = false
	picked.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if picked.visuals:
		picked.visuals.freeze_font_sync_for_fly_phantom = true
	await _prepare_card_menu_pivot(picked)
	if not is_instance_valid(picked):
		return
	if from_global == Vector2.ZERO:
		var vp_center := get_viewport().get_visible_rect().get_center()
		_place_visual_center_at(picked, vp_center)
		picked.rotation = 0.0
		picked.scale = Vector2.ZERO
		picked.visible = true
		await _tween_center_scale_reveal(picked)
		if not is_instance_valid(picked):
			return
		var from_center := picked.get_global_rect().get_center()
		await get_tree().create_timer(CENTER_HOLD_BEFORE_DECK_FLY).timeout
		if not is_instance_valid(picked):
			return
		await _fly_card_menu_to_deck_center(picked, from_center)
	else:
		picked.visible = true
		await _fly_card_menu_to_deck_center(picked, from_global)
	if is_instance_valid(picked):
		picked.queue_free()


func animate_card_to_deck(card: Card, from_global: Vector2) -> void:
	if not deck_button or not card:
		return
	var ghost := CARD_MENU_UI.instantiate() as CardMenuUI
	var layer := get_parent()
	if layer:
		layer.add_child(ghost)
	else:
		add_child(ghost)
	ghost.top_level = true
	ghost.z_index = 200
	ghost.z_as_relative = false
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.card = card
	if ghost.visuals:
		ghost.visuals.freeze_font_sync_for_fly_phantom = true
	ghost.visible = false
	await _prepare_card_menu_pivot(ghost)
	var from: Vector2
	if from_global == Vector2.ZERO:
		var vp_center := get_viewport().get_visible_rect().get_center()
		_place_visual_center_at(ghost, vp_center)
		ghost.rotation = 0.0
		ghost.scale = Vector2.ZERO
		ghost.visible = true
		await _tween_center_scale_reveal(ghost)
		if not is_instance_valid(ghost):
			return
		from = ghost.get_global_rect().get_center()
		await get_tree().create_timer(CENTER_HOLD_BEFORE_DECK_FLY).timeout
	else:
		_place_visual_center_at(ghost, from_global)
		ghost.scale = Vector2.ONE
		ghost.visible = true
		from = from_global
	if not is_instance_valid(ghost):
		return
	await _fly_card_menu_to_deck_center(ghost, from)
	if is_instance_valid(ghost):
		ghost.queue_free()


func _fly_card_menu_to_deck_center(node: CardMenuUI, from: Vector2) -> void:
	var to := _deck_target_center()
	var mid := _bezier_control_draw_bulge_up(from, to)
	var step := RunFlyTweenStep.new()
	step.ghost = node
	step.p0 = from
	step.p1 = mid
	step.p2 = to
	step.spiral_turns = SPIRAL_TURNS
	step.rotation_turns = FLY_ROTATIONS
	node.rotation = 0.0
	step.apply(0.0)
	var tw := create_tween()
	# 由慢渐快：插值前期移动少、后期移动多
	tw.set_ease(Tween.EASE_IN)
	tw.set_trans(Tween.TRANS_QUAD)
	tw.tween_method(Callable(step, "apply"), 0.0, 1.0, FLY_DURATION)
	await tw.finished


func _deck_target_center() -> Vector2:
	if not is_instance_valid(deck_button):
		return Vector2.ZERO
	return deck_button.get_global_rect().get_center()


func _tween_center_scale_reveal(node: Control) -> void:
	if not is_instance_valid(node):
		return
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, CENTER_REVEAL_DURATION)
	await tw.finished


func _place_visual_center_at(ghost: Control, global_center: Vector2) -> void:
	var delta := global_center - ghost.get_global_rect().get_center()
	ghost.global_position += delta


func _prepare_card_menu_pivot(ghost: Control) -> void:
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


func _bezier_control_draw_bulge_up(from: Vector2, to: Vector2) -> Vector2:
	var chord := to - from
	var dist := chord.length()
	if dist < 0.001:
		dist = 0.001
	var perp := Vector2(-chord.y, chord.x).normalized()
	var screen_up := Vector2(0.0, -1.0)
	if perp.dot(screen_up) < 0.0:
		perp = -perp
	var bulge := clampf(dist * 0.3, 36.0, 120.0)
	return (from + to) * 0.5 + perp * bulge


class RunFlyTweenStep extends RefCounted:
	var ghost: Control
	var p0: Vector2
	var p1: Vector2
	var p2: Vector2
	var spiral_turns: float = 2.25
	var rotation_turns: float = 1.0

	func apply(te: float) -> void:
		if not is_instance_valid(ghost):
			return
		var sc := 1.0 - te
		ghost.scale = Vector2.ONE * sc
		var u := 1.0 - te
		var base := u * u * p0 + 2.0 * u * te * p1 + te * te * p2
		var chord := p2 - p0
		var perp := Vector2(-chord.y, chord.x)
		if perp.length() < 0.001:
			perp = Vector2(0.0, 1.0)
		else:
			perp = perp.normalized()
		var dist := chord.length()
		var amp := clampf(dist * 0.14, 18.0, 140.0)
		var envelope := (1.0 - te) * (1.0 - te)
		var spiral_off := -perp * amp * sin(TAU * spiral_turns * te) * envelope
		var pos := base + spiral_off
		var delta := pos - ghost.get_global_rect().get_center()
		ghost.global_position += delta
		ghost.rotation = te * TAU * rotation_turns
