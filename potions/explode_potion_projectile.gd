class_name ExplodePotionProjectile
extends Node2D

const DEFAULT_ICON := preload("res://art/potions/explode_potion.png")
const DEFAULT_LAND_SFX := preload("res://art/potions/explode.ogg")
const DEFAULT_FLIGHT_DURATION := 0.225
const ARC_HEIGHT_RATIO := 0.35
const DISPLAY_SCALE := 3.0
const DRAW_Z_INDEX := 120
const SPIN_TURNS := 2.0

@onready var _sprite: Sprite2D = $Sprite2D

var _icon: Texture2D = DEFAULT_ICON
var _land_sfx: AudioStream = DEFAULT_LAND_SFX
var _flight_duration := DEFAULT_FLIGHT_DURATION
var _min_arc_px := 0.0
var _prev_pos: Vector2
var _travel_angle := 0.0


func _ready() -> void:
	z_as_relative = false
	z_index = DRAW_Z_INDEX
	_sprite.texture = _icon
	_sprite.centered = true
	_sprite.scale = Vector2(DISPLAY_SCALE, DISPLAY_SCALE)


func configure(
	icon: Texture2D,
	land_sfx: AudioStream = null,
	flight_duration: float = DEFAULT_FLIGHT_DURATION,
	min_arc_px: float = 0.0,
) -> void:
	if icon != null:
		_icon = icon
	_land_sfx = land_sfx
	_flight_duration = flight_duration
	_min_arc_px = min_arc_px
	if is_node_ready() and is_instance_valid(_sprite):
		_sprite.texture = _icon


func fly_to(from: Vector2, to: Vector2) -> void:
	if not is_node_ready():
		await ready
	global_position = from
	_prev_pos = from
	_travel_angle = (to - from).angle()
	visible = true
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_method(_set_arc_progress.bind(from, to), 0.0, 1.0, _flight_duration)
	await tween.finished
	if _land_sfx != null:
		SFXPlayer.play(_land_sfx)
	queue_free()


func _set_arc_progress(t: float, from: Vector2, to: Vector2) -> void:
	var pos := _parabolic_point(from, to, t)
	var dir := pos - _prev_pos
	if dir.length_squared() > 0.01:
		_travel_angle = dir.angle()
	_sprite.rotation = _travel_angle + t * SPIN_TURNS * TAU
	global_position = pos
	_prev_pos = pos


func _parabolic_point(from: Vector2, to: Vector2, t: float) -> Vector2:
	var x := lerpf(from.x, to.x, t)
	var base_y := lerpf(from.y, to.y, _ease_out_cubic(t))
	var arc_lift := -maxf(absf(to.x - from.x) * ARC_HEIGHT_RATIO, _min_arc_px)
	var y := base_y + sin(t * PI) * arc_lift
	return Vector2(x, y)


func _ease_out_cubic(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)
