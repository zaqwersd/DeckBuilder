class_name BattleStats
extends Resource

## 由 BattleStatsPool 在进入战斗房间时写入（0 弱怪 / 1 强怪 / 2 精英 / 3 Boss），遭遇 .tres 中不配置。
var battle_tier: int = 0
@export_range(0.0, 10.0) var weight: float
@export var enemies: PackedScene
@export var background_texture: Texture2D  ## 战斗背景图，为空则使用层默认

var accumulated_weight: float = 0.0


func roll_gold_reward(act: int) -> int:
	return BattleGoldRewards.roll(act, battle_tier)


## 用于战斗池去重：精确到某一场遭遇（bats_2.tres 与 bats_3.tres 不同）。
func get_encounter_key() -> String:
	if not resource_path.is_empty():
		return resource_path
	if enemies != null and not enemies.resource_path.is_empty():
		return enemies.resource_path
	return str(get_instance_id())


## 同族遭遇（如 bats_2 / bats_3）视为同类，用于「缺席过久须再现」。
func get_encounter_family_key() -> String:
	if enemies != null and not enemies.resource_path.is_empty():
		var scene_name := enemies.resource_path.get_file().get_basename()
		var underscore := scene_name.find("_")
		if underscore > 0:
			return scene_name.substr(0, underscore)
		return scene_name
	if not resource_path.is_empty():
		return resource_path.get_file().get_basename()
	return str(get_instance_id())
