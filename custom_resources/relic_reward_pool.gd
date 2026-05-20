class_name RelicRewardPool
extends Resource

@export var relics: Array[Relic] = []


func roll_reward(char_stats: CharacterStats, relic_handler: RelicHandler) -> Relic:
	var available := relics.filter(
		func(relic: Relic) -> bool:
			if relic == null:
				return false
			var can_appear := relic.can_appear_as_reward(char_stats)
			var already_had := relic_handler != null and relic_handler.has_relic(relic.id)
			return can_appear and not already_had
	)
	if available.is_empty():
		return null
	return RNG.array_pick_random(available) as Relic
