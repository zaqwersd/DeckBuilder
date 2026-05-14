extends Node2D

const ARC_POINTS := 8

@onready var area_2d: Area2D = $Area2D
@onready var card_arc: Line2D = $CanvasLayer/CardArc

var current_card: CardUI
var targeting := false


func _ready() -> void:
	Events.card_aim_started.connect(_on_card_aim_started)
	Events.card_aim_ended.connect(_on_card_aim_ended)


func _process(_delta: float) -> void:
	if not targeting:
		return

	area_2d.position = get_local_mouse_position()
	var best := _pick_nearest_overlapping_enemy()
	_apply_single_target(best)
	var arc_end_local := get_local_mouse_position()
	if best != null:
		arc_end_local = to_local(_enemy_aim_point_global(best))
	card_arc.points = _get_points(arc_end_local)


## 与鼠标距离：用精灵视觉中心（比 Area2D 原点更贴近玩家指向）。
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
	for a in area_2d.get_overlapping_areas():
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


func _apply_single_target(best: Enemy) -> void:
	if not current_card or not targeting:
		return
	var cur: Node = null
	if current_card.targets.size() == 1:
		cur = current_card.targets[0]
	if cur == best:
		return
	if cur == null and best == null:
		return
	current_card.targets.clear()
	if best != null:
		current_card.targets.append(best)
	current_card.refresh_combat_description()


func _get_points(arc_end_local: Vector2) -> Array:
	var points := []
	var start_g := current_card.global_position
	start_g.x += current_card.size.x * 0.5
	var start_local := to_local(start_g)
	var distance := arc_end_local - start_local

	for i in ARC_POINTS:
		var t := (1.0 / ARC_POINTS) * i
		var x := start_local.x + (distance.x / ARC_POINTS) * i
		var y := start_local.y + ease_out_cubic(t) * distance.y
		points.append(Vector2(x, y))

	points.append(arc_end_local)

	return points


func ease_out_cubic(number: float) -> float:
	return 1.0 - pow(1.0 - number, 3.0)


func _on_card_aim_started(card: CardUI) -> void:
	if not card.card.is_single_targeted():
		return

	targeting = true
	area_2d.monitoring = true
	area_2d.monitorable = true
	current_card = card


func _on_card_aim_ended(_card: CardUI) -> void:
	targeting = false
	card_arc.clear_points()
	area_2d.position = Vector2.ZERO
	area_2d.monitoring = false
	area_2d.monitorable = false
	current_card = null
