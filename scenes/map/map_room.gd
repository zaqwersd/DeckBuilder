class_name MapRoom
extends Area2D

signal clicked(room: Room)
signal selected(room: Room)

const BOSS_MAP_ICONS := preload("res://global/boss_map_icon_util.gd")
const MAP_ICON_SCALE := 3.0
## 64px Boss 专用图沿用与普通 Boss 相同的显示倍率，仅外圈放大以框住图标。
const BOSS_CUSTOM_FRAME_SCALE := 1.32
const BOSS_CUSTOM_FRAME_WIDTH := 11.0
const BOSS_CUSTOM_COLLISION_RADIUS := 58.0
const DEFAULT_FRAME_WIDTH := 9.0
const DEFAULT_COLLISION_RADIUS := 48.0

const ICONS := {
	Room.Type.NOT_ASSIGNED: [null, Vector2.ONE],
	Room.Type.MONSTER: [preload("res://art/tile_0103.png"), Vector2.ONE],
	Room.Type.TREASURE: [preload("res://art/tile_0089.png"), Vector2.ONE],
	Room.Type.CAMPFIRE: [preload("res://art/player_heart.png"), Vector2(0.6, 0.6)],
	Room.Type.SHOP: [preload("res://art/gold.png"), Vector2(0.6, 0.6)],
	Room.Type.BOSS: [preload("res://art/tile_0105.png"), Vector2(1.25, 1.25)],
	Room.Type.EVENT: [preload("res://art/unknown.png"), Vector2(0.9, 0.9)],
	Room.Type.UNKNOWN: [preload("res://art/unknown.png"), Vector2(0.9, 0.9)],
	Room.Type.ELITE: [preload("res://art/tile_0118.png"), Vector2.ONE],
}

@onready var visuals: Node2D = $Visuals
@onready var sprite_2d: Sprite2D = $Visuals/Sprite2D
@onready var line_2d: Line2D = $Visuals/Line2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var available := false : set = set_available
var room: Room : set = set_room


func set_available(new_value: bool) -> void:
	available = new_value
	if not is_node_ready():
		return

	if available:
		animation_player.play("highlight")
	elif room == null or not room.selected:
		animation_player.play("RESET")


func set_room(new_data: Room) -> void:
	room = new_data
	position = room.position
	if is_node_ready():
		_apply_room_visuals()
	else:
		call_deferred("_apply_room_visuals")


func _ready() -> void:
	var circle := collision_shape.shape as CircleShape2D
	if circle != null:
		collision_shape.shape = circle.duplicate()
	if room != null:
		_apply_room_visuals()


func _apply_room_visuals() -> void:
	if room == null or not is_node_ready():
		return

	var icon: Array = _resolve_room_icon()
	var uses_custom_boss := _uses_custom_boss_icon()
	line_2d.rotation_degrees = room.icon_line_rotation
	sprite_2d.texture = icon[0]
	sprite_2d.scale = icon[1] * MAP_ICON_SCALE
	_apply_frame_visuals(uses_custom_boss)
	_ensure_frame_above_icon()


func _uses_custom_boss_icon() -> bool:
	return (
		room.type == Room.Type.BOSS
		and BOSS_MAP_ICONS.uses_custom_map_icon(room.battle_stats)
	)


func _apply_frame_visuals(uses_custom_boss: bool) -> void:
	var frame_points := _make_default_frame_points()
	if uses_custom_boss:
		line_2d.points = _scale_frame_points(frame_points, BOSS_CUSTOM_FRAME_SCALE)
		line_2d.width = BOSS_CUSTOM_FRAME_WIDTH
		_set_collision_radius(BOSS_CUSTOM_COLLISION_RADIUS)
	else:
		line_2d.points = frame_points
		line_2d.width = DEFAULT_FRAME_WIDTH
		_set_collision_radius(DEFAULT_COLLISION_RADIUS)


func _make_default_frame_points() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-36, 36),
		Vector2(0, 54),
		Vector2(36, 27),
		Vector2(45, -27),
		Vector2(0, -54),
		Vector2(-45, -27),
	])


func _scale_frame_points(points: PackedVector2Array, scale_factor: float) -> PackedVector2Array:
	var scaled := PackedVector2Array()
	scaled.resize(points.size())
	for i in points.size():
		scaled[i] = points[i] * scale_factor
	return scaled


func _set_collision_radius(radius: float) -> void:
	var circle := collision_shape.shape as CircleShape2D
	if circle != null:
		circle.radius = radius


func _ensure_frame_above_icon() -> void:
	sprite_2d.z_index = 0
	line_2d.z_index = 1
	visuals.move_child(sprite_2d, 0)
	visuals.move_child(line_2d, visuals.get_child_count() - 1)


func _resolve_room_icon() -> Array:
	if room.type == Room.Type.BOSS:
		var boss_texture: Texture2D = BOSS_MAP_ICONS.get_boss_map_icon(room.battle_stats)
		if boss_texture != null:
			return [boss_texture, ICONS[Room.Type.BOSS][1]]
	var display_type := room.type
	if display_type == Room.Type.EVENT:
		display_type = Room.Type.UNKNOWN
	var fallback: Array = ICONS.get(display_type, ICONS[Room.Type.NOT_ASSIGNED])
	return fallback


func is_pointer_over() -> bool:
	if not is_instance_valid(collision_shape) or collision_shape.shape == null:
		return false
	return CombatPointer.node2d_shape_has_world_point(
		self, collision_shape, get_global_mouse_position()
	)


func get_tooltip_screen_rect() -> Rect2:
	var viewport := get_viewport()
	if viewport == null:
		return Rect2()
	# 锚点固定为房间中心 + 未缩放碰撞半径，不随 highlight 动画 scale 变化。
	var radius := DEFAULT_COLLISION_RADIUS
	var circle := collision_shape.shape as CircleShape2D
	if circle != null:
		radius = circle.radius
	var center := viewport.get_canvas_transform() * global_position
	var diameter := radius * 2.0
	return Rect2(center - Vector2(radius, radius), Vector2(diameter, diameter))


func show_selected() -> void:
	line_2d.modulate = Color(1, 1, 1, 1)


func hide_selected() -> void:
	line_2d.modulate = Color(1, 1, 1, 0)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not available or not event.is_action_pressed("left_mouse"):
		return

	clicked.emit(room)
	animation_player.play("select")


# Called by the AnimationPLayer when the
# "select" animation finishes.
func _on_map_room_selected() -> void:
	selected.emit(room)
