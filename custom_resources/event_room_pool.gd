class_name EventRoomPool
extends Resource

@export var event_rooms: Array[PackedScene]  ## 第1层事件
@export var event_rooms_act2: Array[PackedScene]  ## 第2层事件
@export var event_rooms_act3: Array[PackedScene]  ## 第3层事件


func get_random() -> PackedScene:
	return _pick_from(event_rooms)


## 按层数获取事件（支持三层游戏结构）
func get_random_for_act(act: int) -> PackedScene:
	match act:
		1:
			## 第1层使用原池
			if not event_rooms.is_empty():
				return _pick_from(event_rooms)
		2:
			## 第2层使用中层池（如果为空则回退到原池）
			if not event_rooms_act2.is_empty():
				return _pick_from(event_rooms_act2)
			if not event_rooms.is_empty():
				return _pick_from(event_rooms)
		3:
			## 第3层使用深层池（如果为空则回退到原池）
			if not event_rooms_act3.is_empty():
				return _pick_from(event_rooms_act3)
			if not event_rooms.is_empty():
				return _pick_from(event_rooms)
	
	## 默认回退：尝试所有池
	if not event_rooms.is_empty():
		return _pick_from(event_rooms)
	if not event_rooms_act2.is_empty():
		return _pick_from(event_rooms_act2)
	if not event_rooms_act3.is_empty():
		return _pick_from(event_rooms_act3)
	
	## 所有池都为空，返回null（调用方需要处理）
	push_error("EventRoomPool: 所有事件池都为空！")
	return null


static func _pick_from(pool: Array[PackedScene]) -> PackedScene:
	if pool.is_empty():
		return null
	return RNG.array_pick_random(pool) as PackedScene
