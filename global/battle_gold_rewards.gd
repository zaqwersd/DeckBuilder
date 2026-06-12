class_name BattleGoldRewards
extends RefCounted

## 战斗金币仅由 act（1–3）与 battle_tier（0–3）决定；与具体遭遇无关。
const RANGES: Dictionary = {
	1: {
		0: Vector2i(50, 68),
		1: Vector2i(63, 81),
		2: Vector2i(80, 105),
		3: Vector2i(100, 150),
	},
	2: {
		0: Vector2i(55, 73),
		1: Vector2i(68, 86),
		2: Vector2i(88, 112),
		3: Vector2i(110, 165),
	},
	3: {
		0: Vector2i(60, 78),
		1: Vector2i(73, 91),
		2: Vector2i(95, 120),
		3: Vector2i(120, 175),
	},
}


static func roll(act: int, tier: int) -> int:
	var act_key := clampi(act, 1, 3)
	var tier_key := clampi(tier, 0, 3)
	var by_act: Dictionary = RANGES.get(act_key, RANGES[1])
	var span: Vector2i = by_act.get(tier_key, by_act[0])
	return RNG.instance.randi_range(span.x, span.y)
