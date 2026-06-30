class_name Map
extends Node2D

signal intro_scroll_finished

const SCROLL_SPEED := 67.5
const MAP_ROOM = preload("res://scenes/map/map_room.tscn")
const MAP_LINE = preload("res://scenes/map/map_line.tscn")
const ACT_INTRO_OVERLAY := preload("res://scenes/ui/act_intro_overlay.tscn")
const MAP_SCROLL_INTRO_DURATION := 2.5
const ACT_INTRO_BOSS_HOLD := 0.5

@onready var map_generator: MapGenerator = $MapGenerator
@onready var lines: Node2D = %Lines
@onready var rooms: Node2D = %Rooms
@onready var visuals: Node2D = $Visuals
@onready var camera_2d: Camera2D = $Camera2D

var map_data: Array[Array]
var floors_climbed: int
var last_room: Room
var camera_edge_y: float
var _interaction_locked := false
var _intro_running := false
var _act_intro_overlay: ActIntroOverlay
var _intro_scroll_active := false
var _intro_scroll_from: float
var _intro_scroll_to: float
var _intro_scroll_duration: float
var _intro_scroll_elapsed: float
var _overlay_playing := false
var _tooltip_hovered_map_room: MapRoom = null
var _tooltip_hide_serial: int = 0

## 相机水平锁定在地图中心（避免与 Visuals 平移重复计算后跑偏）
var _camera_anchor_x: float = 0.0
## 纵向滚动范围（地图局部坐标，与房间包围盒一致）
var _camera_scroll_y_min: float = 0.0
var _camera_scroll_y_max: float = 0.0


func _ready() -> void:
	camera_edge_y = MapGenerator.Y_DIST * (MapGenerator.FLOORS - 1)
	# offset 用半视口会让鼠标拾取错位；水平居中改由 position.x 对准地图。
	camera_2d.offset = Vector2.ZERO
	hide()
	camera_2d.enabled = false
	set_process(false)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _interaction_locked:
		return
	
	if event.is_action_pressed("scroll_up"):
		camera_2d.position.y -= SCROLL_SPEED
	elif event.is_action_pressed("scroll_down"):
		camera_2d.position.y += SCROLL_SPEED

	camera_2d.position.y = clampf(camera_2d.position.y, _camera_scroll_y_min, _camera_scroll_y_max)
	camera_2d.position.x = _camera_anchor_x


func generate_new_map(act: int = 1) -> void:
	floors_climbed = 0
	map_data = map_generator.generate_map(act)
	if _map_data_needs_regeneration(map_data):
		push_warning("Map: 房间类型未分配，重新生成地图")
		map_data = map_generator.generate_map(act)
	create_map()
	_prepare_act_intro_camera_hidden()


func load_map(map: Array[Array], floors_completed: int, last_room_climbed: Room, act: int = 1) -> void:
	floors_climbed = floors_completed
	map_data = map
	if _map_data_needs_regeneration(map_data):
		push_warning("Map: 存档地图无效，重新生成")
		map_data = map_generator.generate_map(act)
	last_room = SaveGame.resolve_room_in_map_data(map_data, last_room_climbed)
	create_map()
	
	if floors_climbed > 0:
		unlock_next_rooms()
	else:
		unlock_floor()
	reconcile_visited_flags()


func _map_data_needs_regeneration(data: Array[Array]) -> bool:
	var connected := 0
	var typed := 0
	for floor: Array in data:
		for room: Room in floor:
			if room.next_rooms.is_empty():
				continue
			connected += 1
			if room.type != Room.Type.NOT_ASSIGNED:
				typed += 1
	return connected > 0 and typed == 0


func create_map() -> void:
	## 清理旧地图：删除所有房间和连线
	for child in rooms.get_children():
		child.queue_free()
	for child in lines.get_children():
		child.queue_free()
	
	## 强制立即执行清理（不等待帧）
	for child in rooms.get_children():
		if is_instance_valid(child):
			child.free()
	for child in lines.get_children():
		if is_instance_valid(child):
			child.free()
	
	for current_floor: Array in map_data:
		for room: Room in current_floor:
			if room.next_rooms.size() > 0:
				_spawn_room(room)
	
	# Boss room has no next room but we need to spawn it
	var middle := floori(MapGenerator.MAP_WIDTH * 0.5)
	_spawn_room(map_data[MapGenerator.FLOORS-1][middle])

	var map_width_pixels := MapGenerator.X_DIST * (MapGenerator.MAP_WIDTH - 1)
	visuals.position.x = (get_viewport_rect().size.x - map_width_pixels) / 2
	visuals.position.y = get_viewport_rect().size.y / 2
	_fit_camera_to_map()


func _fit_camera_to_map() -> void:
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	for map_room: MapRoom in rooms.get_children():
		var p: Vector2 = visuals.position + map_room.position
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
	if is_inf(min_x):
		return
	var margin_y := SCROLL_SPEED * 3.0
	_camera_anchor_x = (min_x + max_x) * 0.5
	_camera_scroll_y_min = min_y - margin_y
	_camera_scroll_y_max = max_y + margin_y
	var start_y := clampf((min_y + max_y) * 0.5, _camera_scroll_y_min, _camera_scroll_y_max)
	camera_2d.position = Vector2(_camera_anchor_x, start_y)


func unlock_floor(which_floor: int = floors_climbed) -> void:
	for map_room: MapRoom in rooms.get_children():
		if map_room.room.row == which_floor:
			map_room.available = true


func unlock_next_rooms() -> void:
	last_room = SaveGame.resolve_room_in_map_data(map_data, last_room)
	if last_room == null:
		if floors_climbed <= 0:
			unlock_floor(0)
		return
	if last_room.next_rooms.is_empty():
		return
	for map_room: MapRoom in rooms.get_children():
		if map_room.room == null:
			continue
		for next_room: Room in last_room.next_rooms:
			if map_room.room == next_room:
				map_room.available = true
				break
			if (
				map_room.room.row == next_room.row
				and map_room.room.column == next_room.column
			):
				map_room.available = true
				break


func show_map() -> void:
	show()
	camera_2d.enabled = true
	_enable_tooltip_polling()


func hide_map() -> void:
	_clear_map_room_tooltip()
	_disable_tooltip_polling()
	hide()
	camera_2d.enabled = false


func _process(delta: float) -> void:
	if _intro_scroll_active:
		_intro_scroll_elapsed += delta
		var t := clampf(_intro_scroll_elapsed / _intro_scroll_duration, 0.0, 1.0)
		var eased := _quad_ease_in_out(t)
		_set_intro_camera_y(lerpf(_intro_scroll_from, _intro_scroll_to, eased))
		if t >= 1.0:
			_finish_intro_scroll()
	_update_map_room_tooltip_hover()


func _exit_tree() -> void:
	if _intro_scroll_active:
		_intro_scroll_active = false
		set_process(false)
		intro_scroll_finished.emit()


func _quad_ease_in_out(t: float) -> float:
	# 二次缓入缓出：t=0 与 t=1 时速度为 0，中间加速再减速。
	if t < 0.5:
		return 2.0 * t * t
	var inv := -2.0 * t + 2.0
	return 1.0 - inv * inv * 0.5


func begin_act_intro(act: int) -> void:
	play_act_intro(act)


func play_act_intro(act: int) -> void:
	if _intro_running:
		return
	_intro_running = true
	_interaction_locked = true
	_set_map_rooms_pickable(false)

	hide()
	camera_2d.enabled = true
	var boss_camera_y := _get_boss_center_camera_y()
	camera_2d.position = Vector2(_camera_anchor_x, boss_camera_y)

	if not await _wait_inside_tree():
		_reset_intro_state()
		return

	show()
	_enable_tooltip_polling()

	if _act_intro_overlay == null or not is_instance_valid(_act_intro_overlay):
		_act_intro_overlay = ACT_INTRO_OVERLAY.instantiate() as ActIntroOverlay
		add_child(_act_intro_overlay)

	if not is_inside_tree():
		_reset_intro_state()
		return
	await get_tree().create_timer(ACT_INTRO_BOSS_HOLD).timeout
	if not is_inside_tree():
		_reset_intro_state()
		return

	var start_camera_y := _get_start_floor_center_camera_y()
	_play_overlay(act)

	await get_tree().create_timer(ActIntroOverlay.CURTAIN_HALF_DURATION).timeout
	if not is_inside_tree():
		_reset_intro_state()
		return
	await _scroll_camera_y_smooth(boss_camera_y, start_camera_y, MAP_SCROLL_INTRO_DURATION)

	while _overlay_playing and is_inside_tree():
		await get_tree().process_frame

	_reset_intro_state()


func _play_overlay(act: int) -> void:
	_overlay_playing = true
	await _act_intro_overlay.play(act)
	_overlay_playing = false


func _get_boss_map_room() -> MapRoom:
	for map_room: MapRoom in rooms.get_children():
		if map_room.room != null and map_room.room.type == Room.Type.BOSS:
			return map_room
	return null


func _get_boss_center_camera_y() -> float:
	var boss_room := _get_boss_map_room()
	if boss_room == null:
		return _camera_scroll_y_min
	var boss_world_y := visuals.position.y + boss_room.position.y
	return clampf(boss_world_y, _camera_scroll_y_min, _camera_scroll_y_max)


func _get_start_floor_center_camera_y() -> float:
	var min_y := INF
	var max_y := -INF
	var found := false
	for map_room: MapRoom in rooms.get_children():
		if map_room.room == null or map_room.room.row != 0:
			continue
		found = true
		var world_y := visuals.position.y + map_room.position.y
		min_y = minf(min_y, world_y)
		max_y = maxf(max_y, world_y)
	if not found:
		return _camera_scroll_y_max
	var center_y := (min_y + max_y) * 0.5
	return clampf(center_y, _camera_scroll_y_min, _camera_scroll_y_max)


func _prepare_act_intro_camera_hidden() -> void:
	hide()
	camera_2d.enabled = true
	camera_2d.position = Vector2(_camera_anchor_x, _get_boss_center_camera_y())


func _set_intro_camera_y(y: float) -> void:
	camera_2d.position.y = y
	camera_2d.position.x = _camera_anchor_x


func _scroll_camera_y_smooth(from_y: float, to_y: float, duration: float) -> void:
	if not is_inside_tree():
		_set_intro_camera_y(to_y)
		return
	_intro_scroll_from = from_y
	_intro_scroll_to = to_y
	_intro_scroll_duration = maxf(duration, 0.001)
	_intro_scroll_elapsed = 0.0
	_intro_scroll_active = true
	set_process(true)
	await intro_scroll_finished


func _finish_intro_scroll() -> void:
	if not _intro_scroll_active:
		return
	_intro_scroll_active = false
	_set_intro_camera_y(_intro_scroll_to)
	if visible:
		set_process(true)
	else:
		set_process(false)
	intro_scroll_finished.emit()


func _enable_tooltip_polling() -> void:
	set_process(true)


func _disable_tooltip_polling() -> void:
	if not _intro_scroll_active:
		set_process(false)


func dismiss_room_tooltip_hover() -> void:
	var had_hover := _tooltip_hovered_map_room != null
	_cancel_pending_map_tooltip_hide()
	_tooltip_hovered_map_room = null
	if had_hover:
		Events.map_room_tooltip_hover_hide.emit()


func _update_map_room_tooltip_hover() -> void:
	if not visible:
		_clear_map_room_tooltip()
		return
	var hovered := _map_room_under_pointer()
	if hovered == _tooltip_hovered_map_room:
		if hovered != null:
			Events.map_room_tooltip_hover_reposition.emit(hovered)
		return
	if hovered != null and _tooltip_hovered_map_room != null:
		_cancel_pending_map_tooltip_hide()
		_tooltip_hovered_map_room = hovered
		Events.map_room_tooltip_hover_show.emit(hovered.room, hovered)
		return
	if hovered != null:
		_cancel_pending_map_tooltip_hide()
		_tooltip_hovered_map_room = hovered
		Events.map_room_tooltip_hover_show.emit(hovered.room, hovered)
		return
	if _tooltip_hovered_map_room != null:
		_tooltip_hovered_map_room = null
		_schedule_deferred_map_tooltip_hide()


func _map_room_under_pointer() -> MapRoom:
	for child in rooms.get_children():
		if child is MapRoom and (child as MapRoom).is_pointer_over():
			return child as MapRoom
	return null


func _cancel_pending_map_tooltip_hide() -> void:
	_tooltip_hide_serial += 1


func _schedule_deferred_map_tooltip_hide() -> void:
	_tooltip_hide_serial += 1
	var serial := _tooltip_hide_serial
	call_deferred("_deferred_map_tooltip_hide", serial)


func _deferred_map_tooltip_hide(serial: int) -> void:
	if serial != _tooltip_hide_serial:
		return
	var hovered := _map_room_under_pointer()
	if hovered != null:
		_cancel_pending_map_tooltip_hide()
		_tooltip_hovered_map_room = hovered
		Events.map_room_tooltip_hover_show.emit(hovered.room, hovered)
		return
	Events.map_room_tooltip_hover_hide.emit()


func _clear_map_room_tooltip() -> void:
	_cancel_pending_map_tooltip_hide()
	if _tooltip_hovered_map_room == null:
		return
	_tooltip_hovered_map_room = null
	Events.map_room_tooltip_hover_hide.emit()


func _reset_intro_state() -> void:
	if _intro_scroll_active:
		_finish_intro_scroll()
	_overlay_playing = false
	_set_map_rooms_pickable(true)
	_interaction_locked = false
	_intro_running = false


func _wait_inside_tree() -> bool:
	if not is_inside_tree():
		return false
	await get_tree().process_frame
	return is_inside_tree()


func _set_map_rooms_pickable(enabled: bool) -> void:
	for map_room: MapRoom in rooms.get_children():
		map_room.input_pickable = enabled


func _spawn_room(room: Room) -> void:
	var new_map_room := MAP_ROOM.instantiate() as MapRoom
	rooms.add_child(new_map_room)
	new_map_room.room = room
	new_map_room.clicked.connect(_on_map_room_clicked)
	new_map_room.selected.connect(_on_map_room_selected)
	_connect_lines(room)
	
	if room.selected:
		new_map_room.show_selected()


func refresh_visited_markers() -> void:
	for map_room: MapRoom in rooms.get_children():
		if map_room.room != null and map_room.room.selected:
			map_room.show_selected()
		else:
			map_room.hide_selected()


func reconcile_visited_flags() -> void:
	last_room = SaveGame.reconcile_map_visited_flags_on(map_data, last_room, floors_climbed)
	refresh_visited_markers()


func _connect_lines(room: Room) -> void:
	if room.next_rooms.is_empty():
		return
		
	for next: Room in room.next_rooms:
		var new_map_line := MAP_LINE.instantiate() as Line2D
		new_map_line.add_point(room.position)
		new_map_line.add_point(next.position)
		lines.add_child(new_map_line)


func _on_map_room_clicked(room: Room) -> void:
	_clear_map_room_tooltip()
	for map_room: MapRoom in rooms.get_children():
		if map_room.room.row == room.row:
			map_room.available = false


func _on_map_room_selected(room: Room) -> void:
	room = SaveGame.resolve_room_in_map_data(map_data, room)
	if room == null:
		return
	room.selected = true
	last_room = room
	floors_climbed += 1
	refresh_visited_markers()
	Events.map_exited.emit(room)
