extends Node

var instance: RandomNumberGenerator


func _ready() -> void:
	initialize()


func initialize() -> void:
	instance = RandomNumberGenerator.new()
	instance.randomize()


## 指定种子开新局（后续种子输入 UI 调用）；与 `set_from_save_data` 一样走同一套 RNG 流。
func initialize_from_seed(which_seed: int) -> void:
	instance = RandomNumberGenerator.new()
	instance.seed = which_seed


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


## 不放回抽多张牌：每一步先在「仍可选的牌」里按稀有度权重 roll 出普通/罕见/稀有之一，再在该稀有度子池内均匀随机一张（商店、战后选牌等）。
## 某稀有度在剩余池里已无时其权重为 0，其余权重相对有效。
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
				Card.Rarity.COMMON:
					commons.append(c)
				_:
					# STARTER、SPECIAL、STATUSES 等不参与权重抽选
					pass
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


## 不放回抽取多个遗物：按 COMMON / UNCOMMON / RARE 权重 roll，再于桶内均匀随机。
## STARTER / SPECIAL 不参与权重桶；SHOP 仅当 shop_counts_as_uncommon 为 true 时归入 UNCOMMON 桶。
func pick_weighted_distinct_relics(
	pool: Array[Relic],
	count: int,
	weight_common: float,
	weight_uncommon: float,
	weight_rare: float,
	shop_counts_as_uncommon: bool = false
) -> Array[Relic]:
	var remaining: Array[Relic] = pool.duplicate()
	var out: Array[Relic] = []
	for _i in range(count):
		if remaining.is_empty():
			break
		var commons: Array[Relic] = []
		var uncommons: Array[Relic] = []
		var rares: Array[Relic] = []
		for r: Relic in remaining:
			match r.rarity:
				Relic.Rarity.UNCOMMON:
					uncommons.append(r)
				Relic.Rarity.SHOP:
					if shop_counts_as_uncommon:
						uncommons.append(r)
				Relic.Rarity.RARE:
					rares.append(r)
				Relic.Rarity.COMMON:
					commons.append(r)
				_:
					pass
		var wc := weight_common if not commons.is_empty() else 0.0
		var wu := weight_uncommon if not uncommons.is_empty() else 0.0
		var wr := weight_rare if not rares.is_empty() else 0.0
		var tw := wc + wu + wr
		var choice: Relic = null
		if tw <= 0.0:
			choice = array_pick_random(remaining) as Relic
		else:
			var roll := instance.randf() * tw
			var bucket: Array[Relic] = rares
			if roll < wc:
				bucket = commons
			elif roll < wc + wu:
				bucket = uncommons
			choice = array_pick_random(bucket) as Relic
		out.append(choice)
		remaining.erase(choice)
	return out


## 不放回抽取药水：按 COMMON / UNCOMMON / RARE / SPECIAL 权重 roll，再于桶内均匀随机。
func pick_weighted_distinct_potions(
	pool: Array[Potion],
	count: int,
	weight_common: float,
	weight_uncommon: float,
	weight_rare: float
) -> Array[Potion]:
	var remaining: Array[Potion] = pool.duplicate()
	var out: Array[Potion] = []
	for _i in range(count):
		if remaining.is_empty():
			break
		var commons: Array[Potion] = []
		var uncommons: Array[Potion] = []
		var rares: Array[Potion] = []
		var specials: Array[Potion] = []
		for p: Potion in remaining:
			match p.rarity:
				Potion.Rarity.UNCOMMON:
					uncommons.append(p)
				Potion.Rarity.RARE:
					rares.append(p)
				Potion.Rarity.SPECIAL:
					specials.append(p)
				Potion.Rarity.COMMON:
					commons.append(p)
				_:
					pass
		var wc := weight_common if not commons.is_empty() else 0.0
		var wu := weight_uncommon if not uncommons.is_empty() else 0.0
		var wr := weight_rare if not rares.is_empty() else 0.0
		var ws := 1.0 if not specials.is_empty() else 0.0
		var tw := wc + wu + wr + ws
		var choice: Potion = null
		if tw <= 0.0:
			choice = array_pick_random(remaining) as Potion
		else:
			var roll := instance.randf() * tw
			var bucket: Array[Potion] = specials
			if roll < wc:
				bucket = commons
			elif roll < wc + wu:
				bucket = uncommons
			elif roll < wc + wu + wr:
				bucket = rares
			choice = array_pick_random(bucket) as Potion
		out.append(choice)
		remaining.erase(choice)
	return out
