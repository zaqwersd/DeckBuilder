class_name Room
extends Resource

enum Type {NOT_ASSIGNED, MONSTER, TREASURE, CAMPFIRE, SHOP, BOSS, EVENT, ELITE, UNKNOWN}

@export var type: Type
@export var row: int
@export var column: int
@export var position: Vector2
## 地图房间图标装饰线朝向（生成地图时 roll，存档可复现）。
@export var icon_line_rotation: int = 0
@export var next_rooms: Array[Room]
@export var selected := false
# This is only used by the MONSTER, BOSS, and ELITE types
@export var battle_stats: BattleStats
# This is only used by the EVENT room type
@export var event_scene: PackedScene
## UNKNOWN 房间首次进入时解析得到的实际类型（地图图标仍为未知）。
@export var unknown_resolved_type: Type = Type.NOT_ASSIGNED


func _to_string() -> String:
	return "%s (%s)" % [column, Type.keys()[type][0]]
