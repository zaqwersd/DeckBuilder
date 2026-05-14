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
## 营火：休息或升级后已生效，但尚未点「离开」；读档时回到仅「离开」界面。
@export var campfire_leave_pending: bool = false

const CAMPFIRE_PENDING_NONE := 0
const CAMPFIRE_PENDING_REST := 1
const CAMPFIRE_PENDING_UPGRADE := 2
## 与 `campfire_pending_kind` 配套：休息前血量 / 升级前卡备份 / 升级后卡（点「离开」时提交）。
@export var campfire_pending_kind: int = 0
@export var campfire_pending_pre_health: int = -1
@export var campfire_committed_health: int = -1
@export var campfire_pending_upgrade_index: int = -1
@export var campfire_pending_card_backup: Card = null
@export var campfire_committed_upgrade_card: Card = null

## 战斗快照：进入战斗时保存的初始状态，用于中途退出后重进时恢复
@export var combat_snapshot: CombatSnapshot = null


func clear_campfire_pending_staging() -> void:
	campfire_leave_pending = false
	campfire_pending_kind = CAMPFIRE_PENDING_NONE
	campfire_pending_pre_health = -1
	campfire_committed_health = -1
	campfire_pending_upgrade_index = -1
	campfire_pending_card_backup = null
	campfire_committed_upgrade_card = null


## 读档：未点「离开」时显示休息前血量 / 升级前卡面。
func apply_campfire_pending_rollback_to(ch: CharacterStats) -> void:
	if not campfire_leave_pending:
		return
	if campfire_pending_kind == CAMPFIRE_PENDING_REST:
		if campfire_pending_pre_health >= 0:
			ch.health = campfire_pending_pre_health
	elif campfire_pending_kind == CAMPFIRE_PENDING_UPGRADE:
		var ix := campfire_pending_upgrade_index
		if (
			ix >= 0
			and ch.deck != null
			and ix < ch.deck.cards.size()
			and campfire_pending_card_backup != null
		):
			ch.deck.cards[ix] = campfire_pending_card_backup.duplicate(true) as Card


## 回地图：提交休息治疗 / 升级结果（与读档回退配对）。
func commit_campfire_pending_to(ch: CharacterStats) -> void:
	if not campfire_leave_pending:
		return
	if campfire_pending_kind == CAMPFIRE_PENDING_REST:
		var post := campfire_committed_health
		if post < 0:
			post = current_health
		if post >= 0:
			ch.health = post
	elif campfire_pending_kind == CAMPFIRE_PENDING_UPGRADE:
		var ix := campfire_pending_upgrade_index
		if (
			ix >= 0
			and ch.deck != null
			and ix < ch.deck.cards.size()
			and campfire_committed_upgrade_card != null
		):
			ch.deck.cards[ix] = campfire_committed_upgrade_card.duplicate(true) as Card


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
