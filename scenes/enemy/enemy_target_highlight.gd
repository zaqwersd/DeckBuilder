class_name EnemyTargetHighlight
extends Node2D

const CORNER_LEN := 14.0
const LINE_WIDTH := 3.0
const COLOR := Color(1.0, 0.95, 0.85, 1.0)

var _corners: Array[Line2D] = []


func _ready() -> void:
	for _i in 4:
		var line := Line2D.new()
		line.width = LINE_WIDTH
		line.default_color = COLOR
		line.antialiased = true
		add_child(line)
		_corners.append(line)
	hide()


func setup_from_local_rect(rect: Rect2) -> void:
	if not rect.has_area():
		hide()
		return
	show()
	var x := rect.position.x
	var y := rect.position.y
	var w := rect.size.x
	var h := rect.size.y
	var l := CORNER_LEN
	_corners[0].points = PackedVector2Array([
		Vector2(x, y + l), Vector2(x, y), Vector2(x + l, y),
	])
	_corners[1].points = PackedVector2Array([
		Vector2(x + w - l, y), Vector2(x + w, y), Vector2(x + w, y + l),
	])
	_corners[2].points = PackedVector2Array([
		Vector2(x + w, y + h - l), Vector2(x + w, y + h), Vector2(x + w - l, y + h),
	])
	_corners[3].points = PackedVector2Array([
		Vector2(x, y + h - l), Vector2(x, y + h), Vector2(x + l, y + h),
	])
