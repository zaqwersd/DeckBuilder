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
