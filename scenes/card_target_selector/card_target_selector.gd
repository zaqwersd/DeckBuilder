extends Node2D

const ARC_POINTS := 8

@onready var card_arc: Line2D = $CanvasLayer/CardArc
@onready var arc_head: Sprite2D = $CanvasLayer/CardArc/ArcHead

var current_card: CardUI
var targeting := false


func _ready() -> void:
	Events.card_aim_started.connect(_on_card_aim_started)
	Events.card_aim_ended.connect(_on_card_aim_ended)
	Events.combat_flow_reset.connect(_on_combat_reset)


func _process(_delta: float) -> void:
	if not targeting:
		return
	var mouse := get_global_mouse_position()
	var best := EnemyTargeting.pick_enemy_under_mouse(mouse, get_tree())
	_apply_single_target(best)
	_refresh_all_feedback(mouse, best)
	var points := PackedVector2Array(_get_points(to_local(mouse)))
	CardTargetingArc.apply_visual(card_arc, arc_head, points, best != null)


func _refresh_all_feedback(mouse: Vector2, best: Enemy) -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		if not node is Enemy:
			continue
		var e := node as Enemy
		e.set_card_targeting_feedback(targeting, e == best, mouse)


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


func _begin_targeting(card: CardUI) -> void:
	if not card.card.is_single_targeted():
		return
	var was_targeting := targeting
	targeting = true
	current_card = card
	if not was_targeting:
		_apply_single_target(null)
		_refresh_all_feedback(get_global_mouse_position(), null)


func _on_card_aim_started(card: CardUI) -> void:
	_begin_targeting(card)


func _on_combat_reset() -> void:
	_end_targeting()


func _on_card_aim_ended(_card: CardUI) -> void:
	_end_targeting()


func _end_targeting() -> void:
	targeting = false
	CardTargetingArc.clear_visual(card_arc, arc_head)
	EnemyTargeting.clear_all_card_targeting_feedback(get_tree())
	current_card = null
