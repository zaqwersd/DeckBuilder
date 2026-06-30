@tool
class_name WaterMonsterEnemyVisual
extends Node2D

const FRAME_IDLE := preload("res://art/water_monster1.png")
const FRAME_2 := preload("res://art/water_monster2.png")
const FRAME_3 := preload("res://art/water_monster3.png")
const BLINK_STEP_SEC := 0.08
## 呼吸式起伏：Body 相对静止水纹上下浮动（像素，略小幅度）
const BOB_RANGE_PX := 4.5
## 半周期时长（吸气/呼气各一段，合起来为一整次呼吸）
const BOB_HALF_CYCLE_SEC := 1.15

const _BLINK_FRAMES: Array[Texture2D] = [
	FRAME_IDLE,
	FRAME_2,
	FRAME_3,
	FRAME_2,
	FRAME_IDLE,
]

var _sprite: Sprite2D
var _body: Node2D
var _body_rest_y: float = 0.0
var _blink_timer: Timer
var _bob_tween: Tween


func _ready() -> void:
	_body = $Body as Node2D
	_sprite = $Body/Sprite2D as Sprite2D
	if not is_instance_valid(_sprite):
		return
	if is_instance_valid(_body):
		_body_rest_y = _body.position.y
	_sprite.texture = FRAME_IDLE
	_sprite.z_index = 1
	apply_shallows_environment_tint()
	if Engine.is_editor_hint():
		return
	_schedule_blink()
	if is_inside_tree():
		_start_bob()
	else:
		tree_entered.connect(_start_bob, CONNECT_ONE_SHOT)


func _schedule_blink() -> void:
	if not is_instance_valid(_sprite):
		return
	if _blink_timer == null:
		_blink_timer = Timer.new()
		_blink_timer.one_shot = true
		add_child(_blink_timer)
		_blink_timer.timeout.connect(_play_blink_sequence)
	_blink_timer.wait_time = randf_range(1.0, 2.0)
	_blink_timer.start()


func _play_blink_sequence() -> void:
	if not is_instance_valid(_sprite):
		return
	var tween := create_tween()
	for frame in _BLINK_FRAMES:
		var tex := frame
		tween.tween_callback(func() -> void:
			if is_instance_valid(_sprite):
				_sprite.texture = tex
		)
		tween.tween_interval(BLINK_STEP_SEC)
	tween.tween_callback(_schedule_blink)


func _start_bob() -> void:
	if not is_instance_valid(_body):
		return
	if is_instance_valid(_bob_tween):
		_bob_tween.kill()
	_body.position.y = _body_rest_y
	_bob_tween = create_tween()
	_bob_tween.set_loops()
	_bob_tween.set_trans(Tween.TRANS_SINE)
	_bob_tween.set_ease(Tween.EASE_IN_OUT)
	# 吸气上浮 → 呼气下沉，循环往复
	_bob_tween.tween_property(_body, "position:y", _body_rest_y - BOB_RANGE_PX, BOB_HALF_CYCLE_SEC)
	_bob_tween.tween_property(_body, "position:y", _body_rest_y + BOB_RANGE_PX, BOB_HALF_CYCLE_SEC)


## 水纹色调与当前层战斗背景 `_setup_background_modulate` 一致（Act1 为蓝绿暗调）。
func apply_shallows_environment_tint() -> void:
	var act := 1
	if not Engine.is_editor_hint():
		var tree := get_tree()
		if tree != null:
			var run := tree.get_first_node_in_group("run") as Run
			if run != null:
				act = run.current_act
	var tint := Battle.get_act_background_modulate(act)
	for node_name in ["ShallowsBack", "ShallowsFront"]:
		var shallow := get_node_or_null(node_name) as Sprite2D
		if shallow != null:
			shallow.modulate = tint
