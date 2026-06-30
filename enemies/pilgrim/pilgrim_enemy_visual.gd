class_name PilgrimEnemyVisual
extends Node2D

## 相对基准尺寸的呼吸缩放（宽 1.05、高 1.01），以脚底为枢轴。
const BREATH_SCALE := Vector2(1.05, 1.01)
const BREATH_HALF_CYCLE_SEC := 1.25

var _breath_pivot: Node2D
var _sprite: Sprite2D
var _breath_tween: Tween


func _ready() -> void:
	_breath_pivot = $BreathPivot as Node2D
	_sprite = $BreathPivot/Sprite2D as Sprite2D
	_setup_bottom_pivot()
	if Engine.is_editor_hint():
		return
	if is_inside_tree():
		_start_breathing()
	else:
		tree_entered.connect(_start_breathing, CONNECT_ONE_SHOT)


func _setup_bottom_pivot() -> void:
	if not is_instance_valid(_breath_pivot) or not is_instance_valid(_sprite) or _sprite.texture == null:
		return
	var half_h := _sprite.texture.get_height() * absf(_sprite.scale.y) * 0.5
	_breath_pivot.position = Vector2(0.0, half_h)
	_sprite.position = Vector2(0.0, -half_h)


func _start_breathing() -> void:
	if not is_instance_valid(_breath_pivot):
		return
	if is_instance_valid(_breath_tween):
		_breath_tween.kill()
	_breath_pivot.scale = Vector2.ONE
	_breath_tween = create_tween()
	_breath_tween.set_loops()
	_breath_tween.set_trans(Tween.TRANS_SINE)
	_breath_tween.set_ease(Tween.EASE_IN_OUT)
	_breath_tween.tween_property(_breath_pivot, "scale", BREATH_SCALE, BREATH_HALF_CYCLE_SEC)
	_breath_tween.tween_property(_breath_pivot, "scale", Vector2.ONE, BREATH_HALF_CYCLE_SEC)
