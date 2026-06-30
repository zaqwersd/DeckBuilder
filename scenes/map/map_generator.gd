class_name MapGenerator
extends Node

const X_DIST := 135.0
const Y_DIST := 112.5
const PLACEMENT_RANDOMNESS := 22.5
## 地图总行数；Boss 在最后一行（第 FLOORS 层，row = FLOORS - 1）
const FLOORS := 16
const MAP_WIDTH := 7
const PATHS := 6
const MONSTER_ROOM_WEIGHT := 12.0
const EVENT_ROOM_WEIGHT := 5.0
const UNKNOWN_ROOM_WEIGHT := EVENT_ROOM_WEIGHT
const ELITE_ROOM_WEIGHT := 5.0
const SHOP_ROOM_WEIGHT := 2.5
const CAMPFIRE_ROOM_WEIGHT := 4.0
## 精英房可出现的最小/最大地图行（含）；第 5–13 层
const ELITE_ROW_MIN := 4
const ELITE_ROW_MAX := 12
const MAX_CONNECTION_ATTEMPTS := 512
const MAX_ROOM_TYPE_ATTEMPTS := 256

@export var battle_stats_pool: BattleStatsPool
@export var event_room_pool: EventRoomPool

const DEFAULT_BATTLE_POOL_PATH := "res://battles/battle_stats_pool.tres"
const DEFAULT_EVENT_POOL_PATH := "res://scenes/event_rooms/event_room_pool.tres"

var random_room_type_weights = {
	Room.Type.MONSTER: 0.0,
	Room.Type.CAMPFIRE: 0.0,
	Room.Type.SHOP: 0.0,
	Room.Type.ELITE: 0.0,
	Room.Type.UNKNOWN: 0.0
}
var random_room_type_total_weight := 0
var map_data: Array[Array]
var current_act: int = 1  ## 当前层数（1-3），用于区分不同层的内容池


func generate_map(act: int = 1) -> Array[Array]:
	current_act = act
	map_data = _generate_initial_grid()
	var starting_points := _get_random_starting_points()
	
	for j in starting_points:
		var current_j := j
		for i in FLOORS - 1:
			current_j = _setup_connection(i, current_j)
			
	if not _ensure_content_pools(act):
		return map_data
	var act_pool := BattleStatsPool.get_pool_for_act(act)
	if act_pool != null:
		act_pool.reset_draw_decks()
	
	_setup_boss_room()
	_setup_random_room_weights()
	_setup_room_types()
	
	return map_data


func _ensure_content_pools(act: int = 1) -> bool:
	if battle_stats_pool == null:
		var pool_path := DEFAULT_BATTLE_POOL_PATH
		match act:
			2:
				pool_path = "res://battles/battle_stats_pool_act2.tres"
			3:
				pool_path = "res://battles/battle_stats_pool_act3.tres"
		if ResourceLoader.exists(pool_path):
			battle_stats_pool = load(pool_path) as BattleStatsPool
	if event_room_pool == null and ResourceLoader.exists(DEFAULT_EVENT_POOL_PATH):
		event_room_pool = load(DEFAULT_EVENT_POOL_PATH) as EventRoomPool
	if battle_stats_pool == null:
		push_error("MapGenerator: battle_stats_pool 未加载，请检查 battles/battle_stats_pool*.tres")
		return false
	return true


func _generate_initial_grid() -> Array[Array]:
	var result: Array[Array] = []
	
	for i in FLOORS:
		var adjacent_rooms: Array[Room]= []
		
		for j in MAP_WIDTH:
			var current_room := Room.new()
			var offset := Vector2(
				RNG.instance.randf(),
				RNG.instance.randf()
			) * PLACEMENT_RANDOMNESS
			current_room.position = Vector2(j * X_DIST, i * -Y_DIST) + offset
			current_room.row = i
			current_room.column = j
			current_room.icon_line_rotation = RNG.instance.randi_range(0, 359)
			current_room.next_rooms = []
			
			# Boss room has a non-random Y
			if i == FLOORS - 1:
				current_room.position.y = (i + 1) * -Y_DIST
			
			adjacent_rooms.append(current_room)
			
		result.append(adjacent_rooms)

	return result


func _get_random_starting_points() -> Array[int]:
	var y_coordinates: Array[int]
	var unique_points: int = 0
	
	while unique_points < 2:
		unique_points = 0
		y_coordinates = []

		for i in PATHS:
			var starting_point := RNG.instance.randi_range(0, MAP_WIDTH - 1)
			if not y_coordinates.has(starting_point):
				unique_points += 1
			
			y_coordinates.append(starting_point)
		
	return y_coordinates


func _setup_connection(i: int, j: int) -> int:
	var next_room: Room = null
	var current_room := map_data[i][j] as Room
	var attempts := 0
	while attempts < MAX_CONNECTION_ATTEMPTS and (not next_room or _would_cross_existing_path(i, j, next_room)):
		attempts += 1
		var random_j := clampi(RNG.instance.randi_range(j - 1, j + 1), 0, MAP_WIDTH - 1)
		next_room = map_data[i + 1][random_j]
	if attempts >= MAX_CONNECTION_ATTEMPTS:
		push_warning("MapGenerator: 连接 (%d,%d) 重试过多，使用直连接" % [i, j])
		next_room = map_data[i + 1][clampi(j, 0, MAP_WIDTH - 1)]
	current_room.next_rooms.append(next_room)
	return next_room.column


func _would_cross_existing_path(i: int, j: int, room: Room) -> bool:
	var left_neighbour: Room
	var right_neighbour: Room
	
	# if j == 0, there's no left neighbour
	if j > 0:
		left_neighbour = map_data[i][j - 1]
	# if j == MAP_WIDTH - 1, there's no right neighbour
	if j < MAP_WIDTH - 1:
		right_neighbour = map_data[i][j + 1]
	
	# can't cross in right dir if right neighbour goes to left
	if right_neighbour and room.column > j:
		for next_room: Room in right_neighbour.next_rooms:
			if next_room.column < room.column:
				return true
	
	# can't cross in left dir if left neighbour goes to right
	if left_neighbour and room.column < j:
		for next_room: Room in left_neighbour.next_rooms:
			if next_room.column > room.column:
				return true
	
	return false


func _setup_boss_room() -> void:
	var middle := floori(MAP_WIDTH * 0.5)
	var boss_room := map_data[FLOORS - 1][middle] as Room
	
	for j in MAP_WIDTH:
		var current_room = map_data[FLOORS - 2][j] as Room
		if current_room.next_rooms:
			current_room.next_rooms = [] as Array[Room]
			current_room.next_rooms.append(boss_room)
			
	boss_room.type = Room.Type.BOSS
	boss_room.battle_stats = battle_stats_pool.get_battle_for_act_and_tier(current_act, 3)


func _setup_random_room_weights() -> void:
	random_room_type_weights[Room.Type.MONSTER] = MONSTER_ROOM_WEIGHT
	random_room_type_weights[Room.Type.CAMPFIRE] = MONSTER_ROOM_WEIGHT + CAMPFIRE_ROOM_WEIGHT
	random_room_type_weights[Room.Type.SHOP] = MONSTER_ROOM_WEIGHT + CAMPFIRE_ROOM_WEIGHT + SHOP_ROOM_WEIGHT
	random_room_type_weights[Room.Type.ELITE] = random_room_type_weights[Room.Type.SHOP] + ELITE_ROOM_WEIGHT
	random_room_type_weights[Room.Type.UNKNOWN] = random_room_type_weights[Room.Type.ELITE] + UNKNOWN_ROOM_WEIGHT
	
	random_room_type_total_weight = random_room_type_weights[Room.Type.UNKNOWN]


func _setup_room_types() -> void:
	# first floor is always a battle
	for room: Room in map_data[0]:
		if room.next_rooms.size() > 0:
				room.type = Room.Type.MONSTER

	# 9th floor is always a treasure
	for room: Room in map_data[8]:
		if room.next_rooms.size() > 0:
				room.type = Room.Type.TREASURE
				
	# Boss 前一整层固定营火
	for room: Room in map_data[FLOORS - 2]:
		if room.next_rooms.size() > 0:
				room.type = Room.Type.CAMPFIRE
	
	# rest of rooms
	for current_floor in map_data:
		for room: Room in current_floor:
			for next_room: Room in room.next_rooms:
				if next_room.type == Room.Type.NOT_ASSIGNED:
					_set_room_randomly(next_room)


func _set_room_randomly(room_to_set: Room) -> void:
	var type_candidate: Room.Type
	var attempts := 0
	
	while attempts < MAX_ROOM_TYPE_ATTEMPTS:
		attempts += 1
		type_candidate = _get_random_room_type_by_weight()
		
		var is_campfire := type_candidate == Room.Type.CAMPFIRE
		var has_campfire_parent := _room_has_parent_of_type(room_to_set, Room.Type.CAMPFIRE)
		var is_shop := type_candidate == Room.Type.SHOP
		var has_shop_parent := _room_has_parent_of_type(room_to_set, Room.Type.SHOP)
		var is_elite := type_candidate == Room.Type.ELITE
		var has_elite_parent := _room_has_parent_of_type(room_to_set, Room.Type.ELITE)
		
		var campfire_below_4 := is_campfire and room_to_set.row < 3
		var consecutive_campfire := is_campfire and has_campfire_parent
		var consecutive_shop := is_shop and has_shop_parent
		var campfire_on_13 := is_campfire and room_to_set.row == FLOORS - 3
		var elite_row_invalid := is_elite and (room_to_set.row < ELITE_ROW_MIN or room_to_set.row > ELITE_ROW_MAX)
		var consecutive_elite := is_elite and has_elite_parent
		
		if not (
			campfire_below_4
			or consecutive_campfire
			or consecutive_shop
			or campfire_on_13
			or elite_row_invalid
			or consecutive_elite
		):
			break
	if attempts >= MAX_ROOM_TYPE_ATTEMPTS:
		push_warning("MapGenerator: 房间 (%d,%d) 类型重试过多，回退为普通战斗" % [room_to_set.row, room_to_set.column])
		type_candidate = Room.Type.MONSTER
		
	room_to_set.type = type_candidate


func _room_has_parent_of_type(room: Room, type: Room.Type) -> bool:
	var parents: Array[Room] = []
	# left parent
	if room.column > 0 and room.row > 0:
		var parent_candidate := map_data[room.row - 1][room.column - 1] as Room
		if parent_candidate.next_rooms.has(room):
			parents.append(parent_candidate)
	# parent below
	if room.row > 0:
		var parent_candidate := map_data[room.row - 1][room.column] as Room
		if parent_candidate.next_rooms.has(room):
			parents.append(parent_candidate)
	# right parent
	if room.column < MAP_WIDTH-1 and room.row > 0:
		var parent_candidate := map_data[room.row - 1][room.column + 1] as Room
		if parent_candidate.next_rooms.has(room):
			parents.append(parent_candidate)
	
	for parent: Room in parents:
		if parent.type == type:
			return true
	
	return false


## 第 1–5 层（row 0–4）弱怪 tier 0；第 6 层起小怪 tier 1
static func battle_tier_for_room(room: Room) -> int:
	var effective_type := room.type
	if room.type == Room.Type.UNKNOWN and room.unknown_resolved_type != Room.Type.NOT_ASSIGNED:
		effective_type = room.unknown_resolved_type
	match effective_type:
		Room.Type.BOSS:
			return 3
		Room.Type.ELITE:
			return 2
		Room.Type.MONSTER:
			if room.row >= 5:
				return 1
			return 0
		_:
			return 0


func _get_random_room_type_by_weight() -> Room.Type:
	var roll := RNG.instance.randf_range(0.0, random_room_type_total_weight)
	
	for type: Room.Type in random_room_type_weights:
		if random_room_type_weights[type] > roll:
			return type
	
	return Room.Type.MONSTER
