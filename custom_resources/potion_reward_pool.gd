class_name PotionRewardPool
extends Resource

@export var potions: Array[Potion] = []


func roll_reward(
	potion_handler: PotionHandler,
	act_number: int = 1,
	run_stats: RunStats = null
) -> Potion:
	if potion_handler != null and not potion_handler.has_empty_slot():
		return null
	var available: Array[Potion] = []
	for p: Potion in potions:
		if p == null or p.id.is_empty():
			continue
		available.append(p.duplicate(true) as Potion)
	if available.is_empty():
		return null
	var weights := run_stats.get_relic_rarity_weights(act_number) if run_stats else {
		"common": RunStats.RELIC_COMMON_WEIGHT,
		"uncommon": RunStats.RELIC_UNCOMMON_WEIGHT,
		"rare": RunStats.RELIC_RARE_WEIGHT,
	}
	var picked := RNG.pick_weighted_distinct_potions(
		available,
		1,
		weights.common,
		weights.uncommon,
		weights.rare
	)
	if picked.is_empty():
		return null
	var template := picked[0] as Potion
	return template.duplicate(true) as Potion
