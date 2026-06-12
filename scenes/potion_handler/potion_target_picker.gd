class_name PotionTargetPicker
extends Node2D

## 战斗内为药水选择单个敌人；左键确认，右键或 ESC 取消。瞄准弧线与攻击牌一致。

signal finished(confirmed: bool, target: Enemy)

const ARC_POINTS := 8

@onready var _aim_arc: Line2D = $CanvasLayer/CardArc
@onready var _arc_head: Sprite2D = $CanvasLayer/CardArc/ArcHead

var _active := false
var _last_confirmed := false
var _await_target: Enemy = null
var _hovered_enemy: Enemy = null
var _aim_anchor: Control


func _ready() -> void:
	hide()
	set_process(false)
	set_process_unhandled_input(false)
	CardTargetingArc.clear_visual(_aim_arc, _arc_head)


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
	CardTargetingArc.clear_visual(_aim_arc, _arc_head)
	show()
	set_process(true)
	set_process_unhandled_input(true)


func _process(_delta: float) -> void:
	if not _active:
		return
	var mouse := get_global_mouse_position()
	_hovered_enemy = EnemyTargeting.pick_enemy_under_mouse(mouse, get_tree())
	_refresh_all_feedback(mouse, _hovered_enemy)
	var points := PackedVector2Array(_get_arc_points(to_local(mouse)))
	CardTargetingArc.apply_visual(_aim_arc, _arc_head, points, _hovered_enemy != null)


func _refresh_all_feedback(mouse: Vector2, best: Enemy) -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		if not node is Enemy:
			continue
		var e := node as Enemy
		e.set_card_targeting_feedback(_active, e == best, mouse)


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


func _end_pick(confirmed: bool, target: Enemy) -> void:
	if not _active:
		return
	_active = false
	_last_confirmed = confirmed
	_await_target = target
	_hovered_enemy = null
	_aim_anchor = null
	CardTargetingArc.clear_visual(_aim_arc, _arc_head)
	EnemyTargeting.clear_all_card_targeting_feedback(get_tree())
	hide()
	set_process(false)
	set_process_unhandled_input(false)
	finished.emit(confirmed, target)
