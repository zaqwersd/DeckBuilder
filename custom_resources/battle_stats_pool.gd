class_name BattleStatsPool
extends Resource

@export var pool: Array[BattleStats]

var total_weights_by_tier := [0.0, 0.0, 0.0]

## 静态缓存，按层存储不同的池实例
static var _act_pools: Dictionary = {}


func _get_all_battles_for_tier(tier: int) -> Array[BattleStats]:
	return pool.filter(
		func(battle: BattleStats):
			return battle.battle_tier == tier
	)


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
			return battle
		
	return null


func setup() -> void:
	for i in 3:
		_setup_weight_for_tier(i)


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
		return act_pool.get_random_battle_for_tier(tier)
	
	## 回退到当前池
	return get_random_battle_for_tier(tier)
