class_name EventRoomPool
extends Resource

@export var event_rooms: Array[PackedScene]  ## 第1层事件
@export var event_rooms_act2: Array[PackedScene]  ## 第2层事件
@export var event_rooms_act3: Array[PackedScene]  ## 第3层事件


func get_random() -> PackedScene:
	return event_rooms.pick_random()


## 按层数获取事件（支持三层游戏结构）
func get_random_for_act(act: int) -> PackedScene:
	match act:
		1:
			## 第1层使用原池
			if not event_rooms.is_empty():
				return event_rooms.pick_random()
		2:
			## 第2层使用中层池（如果为空则回退到原池）
			if not event_rooms_act2.is_empty():
				return event_rooms_act2.pick_random()
			if not event_rooms.is_empty():
				return event_rooms.pick_random()
		3:
			## 第3层使用深层池（如果为空则回退到原池）
			if not event_rooms_act3.is_empty():
				return event_rooms_act3.pick_random()
			if not event_rooms.is_empty():
				return event_rooms.pick_random()
	
	## 默认回退：尝试所有池
	if not event_rooms.is_empty():
		return event_rooms.pick_random()
	if not event_rooms_act2.is_empty():
		return event_rooms_act2.pick_random()
	if not event_rooms_act3.is_empty():
		return event_rooms_act3.pick_random()
	
	## 所有池都为空，返回null（调用方需要处理）
	push_error("EventRoomPool: 所有事件池都为空！")
	return null
