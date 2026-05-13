class_name SaveGame
extends Resource

const SAVE_PATH := "user://savegame.tres"

## Boss 战场景从 toxic_ghost 改名为 evil_spirit 后，旧存档里仍可能引用已删除的 .tscn。
const _TIER2_EVIL_BATTLE_SCENE := preload("res://battles/tier_2_evil_spirit.tscn")

@export var rng_seed: int
@export var rng_state: int
@export var run_stats: RunStats
@export var char_stats: CharacterStats
@export var current_deck: CardPile
@export var current_health: int
@export var relics: Array[Relic]
@export var map_data: Array[Array]
@export var last_room: Room
@export var floors_climbed: int
@export var was_on_map: bool


func save_data() -> void:
	var err := ResourceSaver.save(self, SAVE_PATH)
	assert(err == OK, "无法保存游戏！")


static func load_data() -> SaveGame:
	if FileAccess.file_exists(SAVE_PATH):
		var data := ResourceLoader.load(SAVE_PATH) as SaveGame
		if data:
			_migrate_renamed_battle_scenes(data)
		return data
	
	return null


static func _migrate_renamed_battle_scenes(data: SaveGame) -> void:
	for floor_arr: Array in data.map_data:
		for room: Room in floor_arr:
			_fix_toxic_ghost_battle_scene(room)
	if data.last_room:
		_fix_toxic_ghost_battle_scene(data.last_room)


static func _fix_toxic_ghost_battle_scene(room: Room) -> void:
	if not room or not room.battle_stats:
		return
	var enemies := room.battle_stats.enemies
	var path := enemies.resource_path if enemies else ""
	var stale := path.contains("tier_2_toxic_ghost") or path.contains("/toxic_ghost/")
	var broken_boss := room.battle_stats.battle_tier == 2 and enemies == null
	if stale or broken_boss:
		room.battle_stats.enemies = _TIER2_EVIL_BATTLE_SCENE


static func delete_data() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
