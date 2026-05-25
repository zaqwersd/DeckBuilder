class_name RelicRewardPool
extends Resource

@export var relics: Array[Relic] = []


func roll_reward(
	char_stats: CharacterStats,
	relic_handler: RelicHandler,
	act_number: int = 1,
	run_stats: RunStats = null
) -> Relic:
	var available := relics.filter(
		func(relic: Relic) -> bool:
			if relic == null:
				return false
			if not GameContent.is_relic_enabled_in_game(relic.id):
				return false
			var can_appear := relic.can_appear_as_reward(char_stats)
			var already_had := relic_handler != null and relic_handler.has_relic(relic.id)
			return can_appear and not already_had
	)
	if available.is_empty():
		return null
	var weights := run_stats.get_relic_rarity_weights(act_number) if run_stats else {
		"common": RunStats.RELIC_COMMON_WEIGHT,
		"uncommon": RunStats.RELIC_UNCOMMON_WEIGHT,
		"rare": RunStats.RELIC_RARE_WEIGHT,
	}
	var picked := RNG.pick_weighted_distinct_relics(
		available,
		1,
		weights.common,
		weights.uncommon,
		weights.rare
	)
	return picked[0] if not picked.is_empty() else null
