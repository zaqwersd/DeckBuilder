class_name PotionTargetPicker
extends Node2D

## 战斗内为药水选择单个敌人；左键确认，右键或 ESC 取消。瞄准弧线与攻击牌一致。

signal finished(confirmed: bool, target: Enemy)

const ARC_POINTS := 8

@onready var _area: Area2D = $Area2D
@onready var _aim_arc: Line2D = $CanvasLayer/CardArc

var _active := false
var _last_confirmed := false
var _await_target: Enemy = null
var _hovered_enemy: Enemy = null
var _aim_anchor: Control


func _ready() -> void:
	hide()
	set_process(false)
	set_process_unhandled_input(false)
	_aim_arc.clear_points()


func start_pick_and_wait(aim_anchor: Control = null) -> Array:
	_aim_anchor = aim_anchor
	_last_confirmed = false
	_await_target = null
	start_pick()
	await get_tree().physics_frame
	await finished
	return [_last_confirmed, _await_target]


func start_pick() -> void:
	_active = true
	_last_confirmed = false
	_await_target = null
	_hovered_enemy = null
	_area.monitoring = true
	_area.monitorable = true
	_aim_arc.clear_points()
	show()
	set_process(true)
	set_process_unhandled_input(true)
	_area.position = get_local_mouse_position()


func _process(_delta: float) -> void:
	if not _active:
		return
	_area.position = get_local_mouse_position()
	_hovered_enemy = _pick_nearest_overlapping_enemy()
	var arc_end_local := get_local_mouse_position()
	if _hovered_enemy != null:
		arc_end_local = to_local(_enemy_aim_point_global(_hovered_enemy))
	_aim_arc.points = _get_arc_points(arc_end_local)


func _get_arc_points(arc_end_local: Vector2) -> Array:
	var points: Array[Vector2] = []
	var start_local := to_local(_aim_origin_global())
	var distance := arc_end_local - start_local
	for i in ARC_POINTS:
		var t := (1.0 / ARC_POINTS) * i
		var x := start_local.x + (distance.x / ARC_POINTS) * i
		var y := start_local.y + _ease_out_cubic(t) * distance.y
		points.append(Vector2(x, y))
	points.append(arc_end_local)
	return points


func _ease_out_cubic(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)


func _aim_origin_global() -> Vector2:
	if is_instance_valid(_aim_anchor):
		var rect := _aim_anchor.get_global_rect()
		return rect.position + rect.size * 0.5
	return global_position


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("ui_cancel"):
		_end_pick(false, null)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("right_mouse"):
		_end_pick(false, null)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("left_mouse"):
		if _hovered_enemy != null:
			_end_pick(true, _hovered_enemy)
			get_viewport().set_input_as_handled()


func _enemy_aim_point_global(e: Enemy) -> Vector2:
	if not is_instance_valid(e):
		return Vector2.ZERO
	var spr := e.sprite_2d
	if is_instance_valid(spr) and spr.texture:
		var r := spr.get_rect()
		return e.to_global(spr.position + r.get_center())
	return e.global_position


func _pick_nearest_overlapping_enemy() -> Enemy:
	var best: Enemy = null
	var best_d2 := INF
	var mp := get_global_mouse_position()
	for a in _area.get_overlapping_areas():
		if not a is Enemy:
			continue
		var e := a as Enemy
		if not is_instance_valid(e) or not e.is_inside_tree():
			continue
		var d2 := _enemy_aim_point_global(e).distance_squared_to(mp)
		if d2 < best_d2:
			best_d2 = d2
			best = e
	return best


func _end_pick(confirmed: bool, target: Enemy) -> void:
	if not _active:
		return
	_active = false
	_last_confirmed = confirmed
	_await_target = target
	_hovered_enemy = null
	_aim_anchor = null
	_aim_arc.clear_points()
	_area.monitoring = false
	_area.monitorable = false
	hide()
	set_process(false)
	set_process_unhandled_input(false)
	finished.emit(confirmed, target)
