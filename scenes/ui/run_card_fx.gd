class_name RunCardFx
extends Control

## 地图界面：新卡飞入牌库按钮（奖励 / 商店）
## 飞入牌库：沿上凸贝塞尔，缩放 1→0（与战斗内飞入堆一致）

const CARD_MENU_UI := preload("res://scenes/ui/card_menu_ui.tscn")

var deck_button: Control

const FLY_DURATION := 0.28


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
	await _prepare_card_menu_pivot(picked)
	var from := from_global
	if from == Vector2.ZERO:
		from = picked.get_global_rect().get_center()
	picked.visible = true
	await _fly_card_menu_to_deck_center(picked, from)
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
	ghost.visible = false
	await _prepare_card_menu_pivot(ghost)
	var from: Vector2
	if from_global == Vector2.ZERO:
		var vp_center := get_viewport().get_visible_rect().get_center()
		_place_visual_center_at(ghost, vp_center)
		ghost.scale = Vector2.ONE
		ghost.visible = true
		from = ghost.get_global_rect().get_center()
	else:
		_place_visual_center_at(ghost, from_global)
		ghost.scale = Vector2.ONE
		ghost.visible = true
		from = from_global

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
	step.apply(0.0)
	var tw := create_tween()
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.set_trans(Tween.TRANS_SINE)
	tw.tween_method(Callable(step, "apply"), 0.0, 1.0, FLY_DURATION)
	await tw.finished


func _deck_target_center() -> Vector2:
	if not is_instance_valid(deck_button):
		return Vector2.ZERO
	return deck_button.get_global_rect().get_center()


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

	func apply(te: float) -> void:
		if not is_instance_valid(ghost):
			return
		var sc := 1.0 - te
		ghost.scale = Vector2.ONE * sc
		var u := 1.0 - te
		var pos := u * u * p0 + 2.0 * u * te * p1 + te * te * p2
		var delta := pos - ghost.get_global_rect().get_center()
		ghost.global_position += delta
