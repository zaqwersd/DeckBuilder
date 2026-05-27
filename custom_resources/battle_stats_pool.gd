class_name BattleStatsPool
extends Resource

## 各 tier 遭遇列表；tier 归属仅由此处决定，遭遇 .tres 不写 battle_tier。
## 0 = 弱怪；1 = 强怪；2 = 精英；3 = Boss
@export var tier_0_pool: Array[BattleStats]
@export var tier_1_pool: Array[BattleStats]
@export var tier_2_pool: Array[BattleStats]
@export var tier_3_pool: Array[BattleStats]
## 旧版单列表 pool（已废弃）；若 tier_* 为空且此项有数据，setup 时按遭遇内 battle_tier 拆分。
@export var pool: Array[BattleStats]

var total_weights_by_tier := [0.0, 0.0, 0.0, 0.0]
## 每张地图按 tier 洗牌抽取，用尽后重新洗牌（同 tier 内尽量不重复）
var _draw_decks: Array = []

## 静态缓存，按层存储不同的池实例
static var _act_pools: Dictionary = {}


func _get_tier_pool(tier: int) -> Array[BattleStats]:
	match tier:
		0:
			return tier_0_pool
		1:
			return tier_1_pool
		2:
			return tier_2_pool
		3:
			return tier_3_pool
		_:
			return []


func _get_all_battles_for_tier(tier: int) -> Array[BattleStats]:
	return _get_tier_pool(tier)


func _setup_weight_for_tier(tier: int) -> void:
	var battles := _get_all_battles_for_tier(tier)
	total_weights_by_tier[tier] = 0.0

	for battle: BattleStats in battles:
		total_weights_by_tier[tier] += battle.weight
		battle.accumulated_weight = total_weights_by_tier[tier]


func get_random_battle_for_tier(tier: int) -> BattleStats:
	var roll := randf_range(0.0, total_weights_by_tier[tier])
	var battles := _get_all_battles_for_tier(tier)

	for battle: BattleStats in battles:
		if battle.accumulated_weight > roll:
			return _stamp_tier(battle, tier)

	return null


func _stamp_tier(battle: BattleStats, tier: int) -> BattleStats:
	if battle == null:
		return null
	battle.battle_tier = tier
	return battle


func _refill_draw_deck(tier: int) -> void:
	while _draw_decks.size() <= tier:
		_draw_decks.append([])
	var battles := _get_all_battles_for_tier(tier)
	var deck: Array = []
	for battle: BattleStats in battles:
		deck.append(battle)
	RNG.array_shuffle(deck)
	_draw_decks[tier] = deck


## 从当前 tier 的洗牌牌堆顶抽取一场战斗；该 tier 抽完后重新洗牌再继续。
func draw_battle_for_tier(tier: int) -> BattleStats:
	if tier < 0 or tier >= 4:
		return get_random_battle_for_tier(tier)
	if _draw_decks.size() <= tier or (_draw_decks[tier] as Array).is_empty():
		_refill_draw_deck(tier)
	var deck: Array = _draw_decks[tier]
	if deck.is_empty():
		return get_random_battle_for_tier(tier)
	return _stamp_tier(deck.pop_back() as BattleStats, tier)


func setup() -> void:
	_migrate_legacy_pool_if_needed()
	## 每次生成地图时重建各层池副本，避免静态缓存仍指向旧 pool 内容（例如新加强怪战后热重载仍抽不到）。
	_act_pools.clear()
	_draw_decks.clear()
	for i in 4:
		_setup_weight_for_tier(i)
		_refill_draw_deck(i)


func _migrate_legacy_pool_if_needed() -> void:
	if not pool.is_empty() and tier_0_pool.is_empty() and tier_1_pool.is_empty() and tier_2_pool.is_empty() and tier_3_pool.is_empty():
		for battle: BattleStats in pool:
			if battle == null:
				continue
			var tier: int = clampi(battle.battle_tier, 0, 3)
			match tier:
				0:
					tier_0_pool.append(battle)
				1:
					tier_1_pool.append(battle)
				2:
					tier_2_pool.append(battle)
				3:
					tier_3_pool.append(battle)
		pool.clear()


## 按层数获取对应的池资源（支持三层游戏结构）
static func get_pool_for_act(act: int) -> BattleStatsPool:
	## 检查缓存
	if _act_pools.has(act):
		return _act_pools[act]

	## 根据层数加载对应的池资源
	var pool_path := ""
	match act:
		1:
			pool_path = "res://battles/battle_stats_pool.tres"
		2:
			pool_path = "res://battles/battle_stats_pool_act2.tres"
		3:
			pool_path = "res://battles/battle_stats_pool_act3.tres"
		_:
			pool_path = "res://battles/battle_stats_pool.tres"

	## 检查资源是否存在
	if not ResourceLoader.exists(pool_path):
		push_error("BattleStatsPool: 找不到池资源: " + pool_path)
		return null

	var pool := load(pool_path) as BattleStatsPool
	if pool == null:
		push_error("BattleStatsPool: 无法加载池资源: " + pool_path)
		return null

	## 创建副本避免修改原始资源
	var pool_copy := pool.duplicate(true) as BattleStatsPool
	if pool_copy == null:
		push_error("BattleStatsPool: 无法复制池资源")
		return null

	pool_copy.setup()
	_act_pools[act] = pool_copy
	return pool_copy


## 按层数和tier获取战斗（支持三层游戏结构）
func get_battle_for_act_and_tier(act: int, tier: int) -> BattleStats:
	## 获取对应层的池
	var act_pool := get_pool_for_act(act)
	if act_pool != null and act_pool != self:
		return act_pool.draw_battle_for_tier(tier)

	## 回退到当前池
	return draw_battle_for_tier(tier)
