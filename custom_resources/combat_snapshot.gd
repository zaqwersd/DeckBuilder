class_name CombatSnapshot
extends Resource

## 战斗开始时的状态快照，用于中途退出后重进时恢复

@export var health: int
@export var deck_cards: Array[Card]
## 保存遗物ID而不是Resource引用，避免Resource失效问题
@export var relic_ids: PackedStringArray
@export var room: Room
@export var timestamp: int
## 进入战斗时的RNG状态，确保重进后抽牌结果相同
@export var rng_seed: int
@export var rng_state: int

## 遗物资源缓存（静态，用于在创建和恢复之间传递）
static var _relics_cache: Array[Relic] = []


static func create_from(character: CharacterStats, current_relics: Array[Relic], current_room: Room) -> CombatSnapshot:
	var snapshot := CombatSnapshot.new()
	snapshot.health = character.health
	snapshot.deck_cards = []
	for card in character.deck.cards:
		snapshot.deck_cards.append(card.duplicate(true) as Card)
	
	# 保存遗物ID列表，并将遗物存入静态缓存
	snapshot.relic_ids = PackedStringArray()
	_relics_cache.clear()
	for relic in current_relics:
		if is_instance_valid(relic) and relic != null:
			snapshot.relic_ids.append(relic.id)
			_relics_cache.append(relic)
	
	snapshot.room = current_room
	snapshot.timestamp = Time.get_unix_time_from_system() as int
	# 保存当前RNG状态
	snapshot.rng_seed = RNG.instance.seed
	snapshot.rng_state = RNG.instance.state
	return snapshot


func apply_to(character: CharacterStats, relic_handler: RelicHandler, fallback_relics: Array[Relic] = []) -> void:
	if character == null:
		return
	character.health = health
	if character.deck != null and not deck_cards.is_empty():
		character.deck.cards = []
		for card in deck_cards:
			character.deck.cards.append(card.duplicate(true) as Card)
	if relic_handler != null:
		relic_handler.clear_relics()
		var relics_to_use: Array[Relic] = []
		
		print("CombatSnapshot.apply_to: 缓存=%d个, 后备=%d个" % [_relics_cache.size(), fallback_relics.size()])
		
		if not _relics_cache.is_empty():
			# 使用内存中的缓存（适用于退出到主菜单后继续游戏）
			print("使用内存缓存恢复遗物")
			relics_to_use = _relics_cache.duplicate()
		elif not fallback_relics.is_empty():
			# 使用后备遗物（适用于完全重启游戏后）
			print("使用后备数据恢复遗物")
			relics_to_use = fallback_relics.duplicate()
		
		if not relics_to_use.is_empty():
			relic_handler.add_relics(relics_to_use, false)
			print("apply_to 完成，当前遗物数量: %d" % relic_handler.get_all_relics().size())
		else:
			push_warning("CombatSnapshot.apply_to: 没有遗物可以恢复！")
	# 恢复RNG状态，确保抽牌结果与第一次进入时相同
	RNG.set_from_save_data(rng_seed, rng_state)
