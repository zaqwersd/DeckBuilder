extends Node

var instance: RandomNumberGenerator


func _ready() -> void:
	initialize()


func initialize() -> void:
	instance = RandomNumberGenerator.new()
	instance.randomize()


func set_from_save_data(which_seed: int, state: int) -> void:
	instance = RandomNumberGenerator.new()
	instance.seed = which_seed
	instance.state = state


func array_pick_random(array: Array) -> Variant:
	if array.is_empty():
		return null

	return array[instance.randi() % array.size()]


func array_shuffle(array: Array) -> void:
	if array.size() < 2:
		return

	for i in range(array.size()-1, 0, -1):
		var j := instance.randi() % (i + 1)
		var tmp = array[j]
		array[j] = array[i]
		array[i] = tmp


## 按稀有度权重不放回抽取；某稀有度在剩余池里已无时其权重为 0，其余再归一化（商店、战后卡牌奖励等）。
func pick_weighted_distinct_cards(
	pool: Array[Card],
	count: int,
	weight_common: float,
	weight_uncommon: float,
	weight_rare: float
) -> Array[Card]:
	var remaining: Array[Card] = pool.duplicate()
	var out: Array[Card] = []
	for _i in range(count):
		if remaining.is_empty():
			break
		var commons: Array[Card] = []
		var uncommons: Array[Card] = []
		var rares: Array[Card] = []
		for c: Card in remaining:
			match c.rarity:
				Card.Rarity.UNCOMMON:
					uncommons.append(c)
				Card.Rarity.RARE:
					rares.append(c)
				_:
					commons.append(c)
		var wc := weight_common if not commons.is_empty() else 0.0
		var wu := weight_uncommon if not uncommons.is_empty() else 0.0
		var wr := weight_rare if not rares.is_empty() else 0.0
		var tw := wc + wu + wr
		var choice: Card = null
		if tw <= 0.0:
			choice = array_pick_random(remaining) as Card
		else:
			var roll := instance.randf() * tw
			var bucket: Array[Card] = rares
			if roll < wc:
				bucket = commons
			elif roll < wc + wu:
				bucket = uncommons
			choice = array_pick_random(bucket) as Card
		out.append(choice)
		remaining.erase(choice)
	return out
