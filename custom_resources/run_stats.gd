class_name RunStats
extends Resource

signal gold_changed

const STARTING_GOLD := 70
const BASE_CARD_REWARDS := 3
## 卡牌随机稀有度相对权重：普通 / 罕见 / 稀有 = 17 : 7 : 1（商店、战后选牌等先抽稀有度再在池内均匀抽牌）
const BASE_COMMON_WEIGHT := 17.0
const BASE_UNCOMMON_WEIGHT := 7.0
const BASE_RARE_WEIGHT := 1.0

@export var gold := STARTING_GOLD : set = set_gold
@export var card_rewards := BASE_CARD_REWARDS
@export_range(0.0, 100.0) var common_weight := BASE_COMMON_WEIGHT
@export_range(0.0, 100.0) var uncommon_weight := BASE_UNCOMMON_WEIGHT
@export_range(0.0, 100.0) var rare_weight := BASE_RARE_WEIGHT


func set_gold(new_amount: int) -> void:
	gold = new_amount
	gold_changed.emit()


func reset_weights() -> void:
	common_weight = BASE_COMMON_WEIGHT
	uncommon_weight = BASE_UNCOMMON_WEIGHT
	rare_weight = BASE_RARE_WEIGHT


## ============================================================================
## 动态概率与权重计算（基于当前层数）
## ============================================================================

const MAX_FLOOR_FOR_SCALING := 46  ## 概率达到最大值的层数

## 计算1阶升级概率（从1%线性增加到20%）
func get_upgrade_chance_tier1(floors_climbed: int) -> float:
	var progress := clampi(floors_climbed, 0, MAX_FLOOR_FOR_SCALING) / float(MAX_FLOOR_FOR_SCALING)
	return lerpf(0.01, 0.20, progress)


## 计算2阶升级概率（从0.05%线性增加到2%）
func get_upgrade_chance_tier2(floors_climbed: int) -> float:
	var progress := clampi(floors_climbed, 0, MAX_FLOOR_FOR_SCALING) / float(MAX_FLOOR_FOR_SCALING)
	return lerpf(0.0005, 0.02, progress)


## 根据层数计算动态稀有度权重
## 随着层数增加，稀有卡出现概率逐渐提高
func get_dynamic_weights(floors_climbed: int) -> Dictionary:
	var progress := clampi(floors_climbed, 0, MAX_FLOOR_FOR_SCALING) / float(MAX_FLOOR_FOR_SCALING)
	return {
		"common": lerpf(BASE_COMMON_WEIGHT, 12.0, progress),      ## 从17降到12
		"uncommon": lerpf(BASE_UNCOMMON_WEIGHT, 8.0, progress),   ## 从7升到8
		"rare": lerpf(BASE_RARE_WEIGHT, 4.0, progress)           ## 从1升到4
	}


## 应用稀有度连锁惩罚（降低连续出现同稀有度的概率）
## weights: 当前权重字典
## last_rarity: 上次抽到的稀有度（Card.Rarity）
## streak: 连续同稀有度计数
## 惩罚系数：0.6（每次降低40%）
func apply_rarity_streak_penalty(weights: Dictionary, last_rarity: int, streak: int) -> Dictionary:
	if streak <= 0 or last_rarity < 0:
		return weights
	
	## 0.6^streak，最低保留10%
	var penalty := pow(0.6, streak)
	penalty = maxf(penalty, 0.1)
	
	var result := weights.duplicate()
	match last_rarity:
		Card.Rarity.RARE:
			result.rare *= penalty
		Card.Rarity.UNCOMMON:
			result.uncommon *= penalty
		## Common不应用惩罚，保持基础概率
	
	return result


## 逐步恢复稀有度权重（每次乘1.1，不超过原始值）
## current_weights: 当前已被惩罚的权重
## base_weights: 原始基础权重
## last_rarity: 上次抽到并受惩罚的稀有度
func recover_rarity_weights(current_weights: Dictionary, base_weights: Dictionary, last_rarity: int) -> Dictionary:
	var result := current_weights.duplicate()
	var recovery := 1.1  ## 回升系数
	
	match last_rarity:
		Card.Rarity.RARE:
			## 恢复 Rare 权重，每次乘1.1，但不超过原始值
			result.rare = minf(result.rare * recovery, base_weights.rare)
		Card.Rarity.UNCOMMON:
			## 恢复 Uncommon 权重，每次乘1.1，但不超过原始值
			result.uncommon = minf(result.uncommon * recovery, base_weights.uncommon)
		## Common 不涉及惩罚和恢复
	
	return result
