class_name BattleStats
extends Resource

## battle_tier：0 = 弱怪池（地图前 5 层小怪）；1 = 强怪池（第 6 层起小怪）；2 = Boss 战
@export_range(0, 2) var battle_tier: int
@export_range(0.0, 10.0) var weight: float
@export var gold_reward_min: int
@export var gold_reward_max: int
@export var enemies: PackedScene

var accumulated_weight: float = 0.0


func roll_gold_reward() -> int:
	return RNG.instance.randi_range(gold_reward_min, gold_reward_max)
