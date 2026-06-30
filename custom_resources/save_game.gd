class_name SaveGame
extends Resource

const SAVE_PATH := "user://savegame.tres"

## 注意！！！需要保存的状态包括遗物，卡牌及其升级，金币，生命值，随机数等，切记！！！

@export var rng_seed: int
@export var rng_state: int
@export var run_stats: RunStats
@export var char_stats: CharacterStats
@export var current_deck: CardPile
@export var current_health: int
@export var current_max_health: int = -1
@export var saved_relic_ids: PackedStringArray = PackedStringArray()
@export var saved_potion_ids: PackedStringArray = PackedStringArray()
@export var saved_spent_relic_ids: PackedStringArray = PackedStringArray()
## 与 saved_spent_relic_ids 同步的逗号分隔备份，避免部分环境下 PackedStringArray 未写入 .tres
@export var saved_spent_relic_ids_csv: String = ""
@export var relics: Array[Relic]
@export var map_data: Array[Array]
@export var last_room: Room
@export var floors_climbed: int
@export var was_on_map: bool
@export var act_number: int = 1  ## 当前层数（1-3），用于三层游戏结构
## Act1：第 8 层宝箱奖励界面出现后永久叠加 valley(tense)。
@export var act1_tense_unlocked: bool = false
## Act3：第 8 层宝箱奖励界面出现后永久叠加 sanctuary(tense)。
@export var act3_tense_unlocked: bool = false

## 卡牌奖励稀有度追踪（用于连锁惩罚机制）
@export var last_card_reward_rarity: int = -1  ## 上次卡牌奖励抽到的稀有度
@export var rarity_streak_count: int = 0       ## 连续同稀有度计数

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

const PENDING_NONE := 0
const PENDING_SHOP := 1
const PENDING_TREASURE := 2
const PENDING_EVENT := 3
const PENDING_BATTLE_REWARD := 4

## 房间 RNG 结果缓存：读档后恢复 UI，避免重复 roll 导致与已保存 RNG 流错位。
@export var pending_room_kind: int = PENDING_NONE
@export var pending_event_scene_path: String = ""
@export var pending_event_key: String = ""
## 事件内已消耗的选项（如 gamble 已下注），读档后保持按钮禁用。
@export var pending_event_flags: PackedStringArray = PackedStringArray()
@export var pending_card_template_ids: PackedStringArray = PackedStringArray()
@export var pending_relic_ids: PackedStringArray = PackedStringArray()
@export var pending_potion_ids: PackedStringArray = PackedStringArray()
## 商店 pending_shop_ints：5 卡价、3 遗物价、3 药水价、5 卡售出、3 遗物售出、3 药水售出、删牌次数（共 23）。
@export var pending_shop_ints: PackedInt32Array = PackedInt32Array()

## 战斗奖励画面状态：保存奖励初始状态，用于读档后恢复"什么都没拿"的状态
@export var battle_reward_gold: int = 0
@export var battle_reward_gold_taken: bool = false
@export var battle_reward_relic_ids: PackedStringArray = PackedStringArray()
@export var battle_reward_relics_taken: PackedInt32Array = PackedInt32Array()  ## 0/1 表示每个遗物是否已领取
@export var battle_reward_cards_taken: bool = false  ## 卡牌奖励是否已领取
@export var battle_reward_card_offered: bool = false  ## 是否有「添加新卡牌」按钮（未必已 roll 出三张）
@export var battle_reward_upgrade_offered: bool = false  ## 精英战等：是否有「升级一张牌」按钮
@export var battle_reward_upgrade_taken: bool = false  ## 升级奖励是否已领取
@export var battle_reward_potion_id: String = ""
@export var battle_reward_potion_taken: bool = false

## 战斗奖励：遗物领取暂存状态（类似营火的 pending 机制）
const BATTLE_REWARD_PENDING_NONE := 0
const BATTLE_REWARD_PENDING_RELIC := 1
@export var battle_reward_pending_kind: int = BATTLE_REWARD_PENDING_NONE
@export var battle_reward_pending_relic_index: int = -1  ## 哪个遗物在领取中
@export var battle_reward_pending_pre_health: int = -1
@export var battle_reward_pending_pre_max_health: int = -1
@export var battle_reward_pending_pre_max_mana: int = -1
@export var battle_reward_pending_pre_mana: int = -1
@export var battle_reward_pending_pre_gold: int = -1
@export var battle_reward_pending_pre_deck_cards: Array[Card] = []
@export var battle_reward_pending_pre_relic_ids: PackedStringArray = PackedStringArray()
@export var battle_reward_pending_pre_spent_relic_ids: PackedStringArray = PackedStringArray()
@export var battle_reward_pending_pre_potion_ids: PackedStringArray = PackedStringArray()
@export var battle_reward_pending_pre_rng_seed: int = 0
@export var battle_reward_pending_pre_rng_state: int = 0

## 战斗奖励画面打开时的快照：读档回到「尚未领取任何奖励」的状态（含精英战）
@export var battle_reward_entry_staged: bool = false
@export var battle_reward_entry_pre_health: int = -1
@export var battle_reward_entry_pre_max_health: int = -1
@export var battle_reward_entry_pre_max_mana: int = -1
@export var battle_reward_entry_pre_mana: int = -1
@export var battle_reward_entry_pre_gold: int = -1
@export var battle_reward_entry_pre_deck_cards: Array[Card] = []
@export var battle_reward_entry_pre_relic_ids: PackedStringArray = PackedStringArray()
@export var battle_reward_entry_pre_spent_relic_ids: PackedStringArray = PackedStringArray()
@export var battle_reward_entry_pre_rng_seed: int = 0
@export var battle_reward_entry_pre_rng_state: int = 0
@export var battle_reward_entry_pre_potion_ids: PackedStringArray = PackedStringArray()


func clear_room_pending() -> void:
	pending_room_kind = PENDING_NONE
	pending_event_scene_path = ""
	pending_event_key = ""
	pending_event_flags = PackedStringArray()
	pending_card_template_ids = PackedStringArray()
	pending_relic_ids = PackedStringArray()
	pending_potion_ids = PackedStringArray()
	pending_shop_ints = PackedInt32Array()
	## 同时清除战斗奖励状态
	battle_reward_gold = 0
	battle_reward_gold_taken = false
	battle_reward_relic_ids = PackedStringArray()
	battle_reward_relics_taken = PackedInt32Array()
	battle_reward_cards_taken = false
	battle_reward_card_offered = false
	battle_reward_upgrade_offered = false
	battle_reward_upgrade_taken = false
	battle_reward_potion_id = ""
	battle_reward_potion_taken = false
	clear_battle_reward_entry_staging()
	clear_battle_reward_pending_staging()


func clear_battle_reward_entry_staging() -> void:
	battle_reward_entry_staged = false
	battle_reward_entry_pre_health = -1
	battle_reward_entry_pre_max_health = -1
	battle_reward_entry_pre_max_mana = -1
	battle_reward_entry_pre_mana = -1
	battle_reward_entry_pre_gold = -1
	battle_reward_entry_pre_deck_cards.clear()
	battle_reward_entry_pre_relic_ids.clear()
	battle_reward_entry_pre_spent_relic_ids.clear()
	battle_reward_entry_pre_rng_seed = 0
	battle_reward_entry_pre_rng_state = 0


static func _restore_character_core_stats(
	ch: CharacterStats,
	max_health: int,
	health: int,
	max_mana: int = -1,
	mana: int = -1
) -> void:
	if ch == null:
		return
	if max_health >= 0:
		ch.max_health = max_health
	if health >= 0:
		ch.health = health
	if max_mana >= 0:
		ch.max_mana = max_mana
	if mana >= 0:
		ch.mana = mana


static func _sync_character_stats_to_save(self_ref: SaveGame, ch: CharacterStats) -> void:
	if self_ref == null or ch == null:
		return
	self_ref.current_health = ch.health
	self_ref.current_max_health = ch.max_health


static func collect_spent_relic_ids(from_relics: Array[Relic]) -> PackedStringArray:
	var out := PackedStringArray()
	for relic: Relic in from_relics:
		if relic != null and not relic.id.is_empty() and relic.is_relic_spent():
			out.append(relic.id)
	return out


static func resolve_spent_relic_ids(ids: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	var seen: Dictionary = {}
	for raw_id in ids:
		var id := SaveGameMigrations.resolve_relic_id(String(raw_id))
		if id.is_empty() or seen.has(id):
			continue
		seen[id] = true
		out.append(id)
	return out


static func spent_ids_to_csv(ids: PackedStringArray) -> String:
	if ids.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for id in ids:
		var s := String(id).strip_edges()
		if not s.is_empty():
			parts.append(s)
	return ",".join(parts)


static func spent_ids_from_csv(csv: String) -> PackedStringArray:
	var out := PackedStringArray()
	if csv.is_empty():
		return out
	for part: String in csv.split(","):
		var id := part.strip_edges()
		if not id.is_empty():
			out.append(id)
	return out


func get_resolved_spent_relic_ids() -> PackedStringArray:
	return get_map_spent_relic_ids()


func hydrate_spent_relic_ids_after_load() -> void:
	if not saved_spent_relic_ids.is_empty():
		return
	var from_csv := spent_ids_from_csv(saved_spent_relic_ids_csv)
	if not from_csv.is_empty():
		saved_spent_relic_ids = resolve_spent_relic_ids(from_csv)


## 地图/非战斗：整局持久化的失效遗物 id
func get_map_spent_relic_ids() -> PackedStringArray:
	hydrate_spent_relic_ids_after_load()
	return resolve_spent_relic_ids(saved_spent_relic_ids)


## 战斗中途读档：以 combat_snapshot.spent_relic_ids 为准（进战瞬间，不随本场使用而变）
func get_combat_spent_relic_ids() -> PackedStringArray:
	if combat_snapshot == null:
		return PackedStringArray()
	return resolve_spent_relic_ids(combat_snapshot.spent_relic_ids)


func sync_relic_ids_for_save(from_relics: Array[Relic]) -> void:
	saved_relic_ids = PackedStringArray()
	for relic: Relic in from_relics:
		if relic != null and not relic.id.is_empty():
			saved_relic_ids.append(relic.id)
	relics.clear()


## 地图/战斗结束等：同步遗物 id 与整局失效状态
func sync_relics_for_save(from_relics: Array[Relic]) -> void:
	sync_relic_ids_for_save(from_relics)
	saved_spent_relic_ids = PackedStringArray()
	for relic: Relic in from_relics:
		if relic != null and not relic.id.is_empty() and relic.is_relic_spent():
			saved_spent_relic_ids.append(relic.id)
	saved_spent_relic_ids = resolve_spent_relic_ids(saved_spent_relic_ids)
	saved_spent_relic_ids_csv = spent_ids_to_csv(saved_spent_relic_ids)


func get_effective_relic_ids() -> PackedStringArray:
	if not saved_relic_ids.is_empty():
		return saved_relic_ids
	var out := PackedStringArray()
	for relic: Relic in relics:
		if relic != null and not relic.id.is_empty():
			out.append(relic.id)
	return out


func sync_potion_ids_for_save(from_ids: PackedStringArray) -> void:
	saved_potion_ids = from_ids.duplicate()


func get_effective_potion_ids() -> PackedStringArray:
	var out := PackedStringArray()
	var slot_count := maxi(PotionHandler.DEFAULT_SLOTS, saved_potion_ids.size())
	out.resize(slot_count)
	for i in range(slot_count):
		out[i] = ""
	if saved_potion_ids.is_empty():
		return out
	for i in range(mini(slot_count, saved_potion_ids.size())):
		out[i] = String(saved_potion_ids[i])
	return out


func clear_campfire_pending_staging() -> void:
	campfire_leave_pending = false
	campfire_pending_kind = CAMPFIRE_PENDING_NONE
	campfire_pending_pre_health = -1
	campfire_committed_health = -1
	campfire_pending_upgrade_index = -1
	campfire_pending_card_backup = null
	campfire_committed_upgrade_card = null


func clear_battle_reward_pending_staging() -> void:
	battle_reward_pending_kind = BATTLE_REWARD_PENDING_NONE
	battle_reward_pending_relic_index = -1
	battle_reward_pending_pre_health = -1
	battle_reward_pending_pre_max_health = -1
	battle_reward_pending_pre_max_mana = -1
	battle_reward_pending_pre_mana = -1
	battle_reward_pending_pre_gold = -1
	battle_reward_pending_pre_deck_cards.clear()
	battle_reward_pending_pre_relic_ids.clear()
	battle_reward_pending_pre_spent_relic_ids.clear()
	battle_reward_pending_pre_potion_ids.clear()
	battle_reward_pending_pre_rng_seed = 0
	battle_reward_pending_pre_rng_state = 0


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


## 战斗奖励画面打开时保存快照（尚未领取金币/卡牌/遗物）
func stage_battle_reward_entry_snapshot(
	character: CharacterStats,
	relic_handler: RelicHandler,
	rng_seed: int,
	rng_state: int,
	potion_handler: PotionHandler = null
) -> void:
	if character == null:
		return
	battle_reward_entry_pre_health = character.health
	battle_reward_entry_pre_max_health = character.max_health
	battle_reward_entry_pre_max_mana = character.max_mana
	battle_reward_entry_pre_mana = character.mana
	battle_reward_entry_pre_gold = run_stats.gold if run_stats != null else -1
	battle_reward_entry_pre_deck_cards.clear()
	if character.deck != null:
		for card in character.deck.cards:
			battle_reward_entry_pre_deck_cards.append(card.duplicate(true) as Card)
	battle_reward_entry_pre_relic_ids.clear()
	battle_reward_entry_pre_spent_relic_ids.clear()
	if relic_handler != null:
		for r: Relic in relic_handler.get_all_relics():
			if is_instance_valid(r) and r.id != "":
				battle_reward_entry_pre_relic_ids.append(r.id)
		battle_reward_entry_pre_spent_relic_ids = collect_spent_relic_ids(
			relic_handler.get_all_relics()
		)
	battle_reward_entry_pre_rng_seed = rng_seed
	battle_reward_entry_pre_rng_state = rng_state
	battle_reward_entry_pre_potion_ids = PackedStringArray()
	if potion_handler != null:
		battle_reward_entry_pre_potion_ids = potion_handler.get_ids_for_save()
	battle_reward_entry_staged = true


## 读档：回到战斗刚结束、尚未领取任何战斗奖励时的状态
func apply_battle_reward_entry_rollback_to(
	ch: CharacterStats,
	relic_handler: RelicHandler,
	potion_handler: PotionHandler = null
) -> void:
	if not battle_reward_entry_staged:
		return
	if relic_handler != null:
		relic_handler.revert_persistent_pickups_not_in(
			ch, battle_reward_entry_pre_relic_ids
		)
	_restore_character_core_stats(
		ch,
		battle_reward_entry_pre_max_health,
		battle_reward_entry_pre_health,
		battle_reward_entry_pre_max_mana,
		battle_reward_entry_pre_mana
	)
	_restore_run_stats_gold(battle_reward_entry_pre_gold)
	if ch.deck != null and not battle_reward_entry_pre_deck_cards.is_empty():
		ch.deck.cards.clear()
		for card in battle_reward_entry_pre_deck_cards:
			ch.deck.cards.append(card.duplicate(true) as Card)
	if relic_handler != null:
		relics = relic_handler.restore_relics_from_ids(
			battle_reward_entry_pre_relic_ids,
			false,
			true,
			battle_reward_entry_pre_spent_relic_ids
		)
	if potion_handler != null:
		potion_handler.restore_from_ids(battle_reward_entry_pre_potion_ids)

	_sync_character_stats_to_save(self, ch)
	RNG.set_from_save_data(battle_reward_entry_pre_rng_seed, battle_reward_entry_pre_rng_state)


## 战斗奖励：读档时回退到领取遗物前的状态（未完成领取时）
func apply_battle_reward_pending_rollback_to(ch: CharacterStats, relic_handler: RelicHandler, potion_handler: PotionHandler = null) -> void:
	if battle_reward_pending_kind == BATTLE_REWARD_PENDING_NONE:
		return
	
	if (
		battle_reward_pending_kind == BATTLE_REWARD_PENDING_RELIC
		and battle_reward_pending_relic_index >= 0
		and battle_reward_pending_relic_index < battle_reward_relic_ids.size()
		and relic_handler != null
	):
		relic_handler.revert_pending_relic_pickup_if_applied(
			ch,
			battle_reward_relic_ids[battle_reward_pending_relic_index],
			battle_reward_pending_pre_max_health,
			battle_reward_pending_pre_max_mana
		)
	
	if relic_handler != null:
		relic_handler.revert_persistent_pickups_not_in(
			ch, battle_reward_pending_pre_relic_ids
		)
	
	_restore_character_core_stats(
		ch,
		battle_reward_pending_pre_max_health,
		battle_reward_pending_pre_health,
		battle_reward_pending_pre_max_mana,
		battle_reward_pending_pre_mana
	)
	
	## 恢复金币
	_restore_run_stats_gold(battle_reward_pending_pre_gold)
	
	## 恢复卡组
	if ch.deck != null and not battle_reward_pending_pre_deck_cards.is_empty():
		ch.deck.cards.clear()
		for card in battle_reward_pending_pre_deck_cards:
			ch.deck.cards.append(card.duplicate(true) as Card)
	
	## 恢复遗物
	if relic_handler != null:
		relics = relic_handler.restore_relics_from_ids(
			battle_reward_pending_pre_relic_ids,
			false,
			true,
			battle_reward_pending_pre_spent_relic_ids
		)
	if potion_handler != null:
		potion_handler.restore_from_ids(battle_reward_pending_pre_potion_ids)
	ch.stats_changed.emit()

	_sync_character_stats_to_save(self, ch)
	## 恢复RNG状态
	RNG.set_from_save_data(battle_reward_pending_pre_rng_seed, battle_reward_pending_pre_rng_state)
	if (
		battle_reward_pending_kind == BATTLE_REWARD_PENDING_RELIC
		and battle_reward_pending_relic_index >= 0
		and battle_reward_pending_relic_index < battle_reward_relics_taken.size()
	):
		battle_reward_relics_taken[battle_reward_pending_relic_index] = 0


func save_data() -> void:
	var err := ResourceSaver.save(self, SAVE_PATH)
	assert(err == OK, "无法保存游戏！")


static func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


static func load_data() -> SaveGame:
	if FileAccess.file_exists(SAVE_PATH):
		var data := SaveGameMigrations.load_save_game_resource(SAVE_PATH)
		if data:
			SaveGameMigrations.migrate(data)
			SaveGameMigrations.sanitize_saved_relics(data)
			data.hydrate_spent_relic_ids_after_load()
			sync_saved_map_room_refs(data)
			reconcile_map_visited_flags(data)
		return data
	
	return null


## 深拷贝地图网格，保留每个 Room 的 selected 与 next_rooms 引用关系（浅拷贝会共享实例导致存档丢失路径标记）。
static func duplicate_map_data(source: Array[Array]) -> Array[Array]:
	if source.is_empty():
		return []
	var unique: Array[Room] = []
	for floor_arr: Array in source:
		for room: Room in floor_arr:
			if room != null and not unique.has(room):
				unique.append(room)
	var mapped: Dictionary = {}
	for room: Room in unique:
		var copy := room.duplicate(true) as Room
		copy.next_rooms = []
		mapped[room] = copy
	for room: Room in unique:
		var copy: Room = mapped[room]
		for next_room: Room in room.next_rooms:
			if next_room != null and mapped.has(next_room):
				copy.next_rooms.append(mapped[next_room])
	var result: Array[Array] = []
	for floor_arr: Array in source:
		var new_floor: Array[Room] = []
		for room: Room in floor_arr:
			new_floor.append(mapped[room] if room != null else null)
		result.append(new_floor)
	return result


## 将可能来自旧 map_data 实例的 Room 对齐到当前 map_data 网格中的对应房间（按 row/column）。
static func resolve_room_in_map_data(map_data: Array[Array], room: Room) -> Room:
	if room == null or map_data.is_empty():
		return null
	if room.row < 0 or room.row >= map_data.size():
		return null
	var floor_arr: Array = map_data[room.row]
	if room.column < 0 or room.column >= floor_arr.size():
		return null
	var on_map: Room = floor_arr[room.column] as Room
	if on_map == null:
		return null
	if on_map == room:
		return room
	for floor: Array in map_data:
		for r: Room in floor:
			if r == room:
				return r
	return on_map


## 存档 map_data 深拷贝后，last_room / combat_snapshot.room 等须指向新网格内的实例。
static func sync_saved_map_room_refs(data: SaveGame) -> void:
	if data == null or data.map_data.is_empty():
		return
	data.last_room = resolve_room_in_map_data(data.map_data, data.last_room)
	if data.combat_snapshot != null and data.combat_snapshot.room != null:
		data.combat_snapshot.room = resolve_room_in_map_data(
			data.map_data, data.combat_snapshot.room
		)


## 根据 last_room 重建已走路径的 selected，清除岔路误标/漏标。返回对齐后的 last_room。
static func reconcile_map_visited_flags_on(
	map_data: Array[Array],
	last_room: Room,
	floors_climbed: int
) -> Room:
	if map_data.is_empty():
		return last_room
	var was_selected: Dictionary = {}
	for floor_arr: Array in map_data:
		for room: Room in floor_arr:
			if room != null:
				was_selected[room] = room.selected
	for floor_arr: Array in map_data:
		for room: Room in floor_arr:
			if room != null:
				room.selected = false
	if floors_climbed <= 0 or last_room == null:
		return last_room
	var current := resolve_room_in_map_data(map_data, last_room)
	if current == null:
		return last_room
	while current != null:
		current.selected = true
		if current.row <= 0:
			break
		var parent := _find_best_parent_on_path(map_data, current, was_selected)
		if parent == null:
			break
		current = parent
	return resolve_room_in_map_data(map_data, last_room)


static func reconcile_map_visited_flags(data: SaveGame) -> void:
	if data == null:
		return
	data.last_room = reconcile_map_visited_flags_on(
		data.map_data, data.last_room, data.floors_climbed
	)


static func _collect_parents_on_map(map_data: Array[Array], room: Room) -> Array[Room]:
	var target := resolve_room_in_map_data(map_data, room)
	var parents: Array[Room] = []
	if target == null or target.row <= 0:
		return parents
	for candidate: Room in map_data[target.row - 1]:
		if candidate == null:
			continue
		for next_room: Room in candidate.next_rooms:
			var resolved_next := resolve_room_in_map_data(map_data, next_room)
			if resolved_next == target and not parents.has(candidate):
				parents.append(candidate)
				break
	return parents


static func _find_best_parent_on_path(
	map_data: Array[Array],
	room: Room,
	was_selected: Dictionary
) -> Room:
	var parents := _collect_parents_on_map(map_data, room)
	if parents.is_empty():
		return null
	for parent: Room in parents:
		if was_selected.get(parent, false):
			return parent
	var target := resolve_room_in_map_data(map_data, room)
	if target == null:
		return parents[0]
	parents.sort_custom(func(a: Room, b: Room) -> bool:
		return absi(a.column - target.column) < absi(b.column - target.column)
	)
	return parents[0]


static func delete_data() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


## ============================================================================
## 场景进入快照：用于商店、事件、宝藏等场景重进时恢复到刚进入时的状态
## ============================================================================

## 场景进入时的角色状态快照
@export var scene_entry_health: int = -1
@export var scene_entry_max_health: int = -1
@export var scene_entry_max_mana: int = -1
@export var scene_entry_mana: int = -1
@export var scene_entry_gold: int = -1
@export var scene_entry_deck_cards: Array[Card] = []
@export var scene_entry_relic_ids: PackedStringArray = PackedStringArray()
@export var scene_entry_potion_ids: PackedStringArray = PackedStringArray()
@export var scene_entry_spent_relic_ids: PackedStringArray = PackedStringArray()
@export var scene_entry_rng_seed: int = 0
@export var scene_entry_rng_state: int = 0
@export var scene_entry_room_type: int = -1
@export var has_scene_entry_snapshot: bool = false


func save_scene_entry_snapshot(
	room_type: int,
	character: CharacterStats,
	relics: Array[Relic],
	rng_seed: int,
	rng_state: int,
	potion_handler: PotionHandler = null
) -> void:
	"""保存进入场景时的初始状态快照"""
	if character == null:
		return
	
	scene_entry_room_type = room_type
	scene_entry_health = character.health
	scene_entry_max_health = character.max_health
	scene_entry_max_mana = character.max_mana
	scene_entry_mana = character.mana
	scene_entry_gold = run_stats.gold if run_stats else 0
	
	# 保存卡组
	scene_entry_deck_cards.clear()
	if character.deck != null:
		for card in character.deck.cards:
			scene_entry_deck_cards.append(card.duplicate(true) as Card)
	
	# 保存遗物 ID 与一次性遗物的失效状态
	scene_entry_relic_ids.clear()
	scene_entry_spent_relic_ids.clear()
	for relic in relics:
		if is_instance_valid(relic) and relic != null:
			scene_entry_relic_ids.append(relic.id)
	scene_entry_spent_relic_ids = collect_spent_relic_ids(relics)
	scene_entry_potion_ids = PackedStringArray()
	if potion_handler != null:
		scene_entry_potion_ids = potion_handler.get_ids_for_save()
	
	scene_entry_rng_seed = rng_seed
	scene_entry_rng_state = rng_state
	has_scene_entry_snapshot = true


func apply_scene_entry_snapshot(
	character: CharacterStats,
	relic_handler: RelicHandler,
	potion_handler: PotionHandler = null
) -> bool:
	"""应用场景进入时的快照状态，返回是否成功应用"""
	if not has_scene_entry_snapshot or character == null:
		return false
	
	if relic_handler != null:
		relic_handler.revert_persistent_pickups_not_in(
			character, scene_entry_relic_ids
		)
	
	# 恢复生命值与拾起型遗物可能改动的上限
	_restore_character_core_stats(
		character,
		scene_entry_max_health,
		scene_entry_health,
		scene_entry_max_mana,
		scene_entry_mana
	)
	
	# 恢复金币
	_restore_run_stats_gold(scene_entry_gold)
	
	# 恢复卡组
	if character.deck != null and not scene_entry_deck_cards.is_empty():
		character.deck.cards.clear()
		for card in scene_entry_deck_cards:
			character.deck.cards.append(card.duplicate(true) as Card)
	
	# 恢复遗物
	if relic_handler != null:
		relic_handler.restore_relics_from_ids(
			scene_entry_relic_ids, false, false, scene_entry_spent_relic_ids
		)
	if potion_handler != null:
		potion_handler.restore_from_ids(scene_entry_potion_ids)
	
	# 恢复RNG状态
	RNG.set_from_save_data(scene_entry_rng_seed, scene_entry_rng_state)
	_sync_character_stats_to_save(self, character)
	
	return true


func _restore_run_stats_gold(amount: int) -> void:
	if run_stats != null and amount >= 0:
		run_stats.set_gold(amount)


func clear_scene_entry_snapshot() -> void:
	"""清除场景快照"""
	has_scene_entry_snapshot = false
	scene_entry_room_type = -1
	scene_entry_health = -1
	scene_entry_max_health = -1
	scene_entry_max_mana = -1
	scene_entry_mana = -1
	scene_entry_gold = -1
	scene_entry_deck_cards.clear()
	scene_entry_relic_ids.clear()
	scene_entry_potion_ids.clear()
	scene_entry_spent_relic_ids.clear()
	scene_entry_rng_seed = 0
	scene_entry_rng_state = 0
