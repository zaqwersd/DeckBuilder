class_name BattleStats
extends Resource

## 由 BattleStatsPool 在分配房间时写入（0 弱怪 / 1 强怪 / 2 精英 / 3 Boss），遭遇 .tres 中不配置。
var battle_tier: int = 0
@export_range(0.0, 10.0) var weight: float
@export var gold_reward_min: int
@export var gold_reward_max: int
@export var enemies: PackedScene
@export var background_texture: Texture2D  ## 战斗背景图，为空则使用层默认

var accumulated_weight: float = 0.0


func roll_gold_reward() -> int:
	return RNG.instance.randi_range(gold_reward_min, gold_reward_max)
