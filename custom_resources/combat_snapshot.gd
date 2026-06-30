class_name CombatSnapshot
extends Resource

## 战斗开始时的状态快照，用于中途退出后重进时恢复

@export var health: int
@export var deck_cards: Array[Card]
## 保存遗物ID而不是Resource引用，避免Resource失效问题
@export var relic_ids: PackedStringArray
@export var potion_ids: PackedStringArray = PackedStringArray()
## 进战瞬间的失效状态（仅 create_from 写入；战斗中途保存不修改，读档回退到此）
@export var spent_relic_ids: PackedStringArray = PackedStringArray()
@export var room: Room
@export var battle_stats: BattleStats
@export var timestamp: int
## 进入战斗时的RNG状态，确保重进后抽牌结果相同
@export var rng_seed: int
@export var rng_state: int
## 战斗 setup 完成后的 RNG（洗牌 + 敌人生成/意图分配之后），读档时对齐到首次进战。
@export var setup_rng_seed: int = 0
@export var setup_rng_state: int = 0
@export var has_setup_rng: bool = false
## setup 完成后的抽牌堆顺序（读档跳过洗牌，直接恢复）。
@export var draw_pile_cards: Array[Card] = []
@export var discard_pile_cards: Array[Card] = []
@export var exhaust_pile_cards: Array[Card] = []
## 影武士四回合循环（3 攻击随机序 + 强化）的 RNG 洗牌结果；读档回到战斗开始时，步进从第 1 个意图开始。
@export var shadow_samurai_cycle_slots: PackedInt32Array = PackedInt32Array()
## elements 战斗：Enemy 节点名 → stats 资源路径（读档固定组合）。
@export var elemental_spawn_stat_paths: Dictionary = {}
## elements 等敌人 AI 随机状态（Enemy 节点名 → 字典）。
@export var elemental_enemy_ai_states: Dictionary = {}


func has_shadow_samurai_cycle() -> bool:
	return shadow_samurai_cycle_slots.size() == 4


func has_post_setup_state() -> bool:
	return has_setup_rng


func capture_post_setup(character: CharacterStats) -> void:
	if character == null:
		return
	draw_pile_cards.clear()
	discard_pile_cards.clear()
	exhaust_pile_cards.clear()
	for card: Card in character.draw_pile.cards:
		draw_pile_cards.append(card.duplicate(true) as Card)
	for card: Card in character.discard.cards:
		discard_pile_cards.append(card.duplicate(true) as Card)
	for card: Card in character.exhaust.cards:
		exhaust_pile_cards.append(card.duplicate(true) as Card)
	setup_rng_seed = RNG.instance.seed
	setup_rng_state = RNG.instance.state
	has_setup_rng = true


func restore_battle_piles(character: CharacterStats) -> bool:
	if character == null or not has_post_setup_state():
		return false
	character.draw_pile = _duplicate_pile(draw_pile_cards)
	character.draw_pile.card_pile_size_changed.emit(character.draw_pile.cards.size())
	character.discard = _duplicate_pile(discard_pile_cards)
	character.exhaust = _duplicate_pile(exhaust_pile_cards)
	return true


static func _duplicate_pile(source: Array[Card]) -> CardPile:
	var pile := CardPile.new()
	for card: Card in source:
		var copy := card.duplicate(true) as Card
		copy.sync_upgraded_flags()
		pile.cards.append(copy)
	return pile

static func create_from(
	character: CharacterStats,
	current_relics: Array[Relic],
	current_room: Room,
	potion_handler: PotionHandler = null
) -> CombatSnapshot:
	var snapshot := CombatSnapshot.new()
	snapshot.health = character.health
	snapshot.deck_cards = []
	for card in character.deck.cards:
		snapshot.deck_cards.append(card.duplicate(true) as Card)
	
	# 仅保存遗物 ID 与进入战斗时的失效状态（实例由读档时按 ID 重建）
	snapshot.relic_ids = PackedStringArray()
	snapshot.spent_relic_ids = SaveGame.collect_spent_relic_ids(current_relics)
	for relic in current_relics:
		if is_instance_valid(relic) and relic != null and not relic.id.is_empty():
			snapshot.relic_ids.append(relic.id)
	
	if potion_handler != null:
		snapshot.potion_ids = _normalize_potion_ids(potion_handler.get_ids_for_save())
	else:
		snapshot.potion_ids = _empty_potion_ids()
	snapshot.room = current_room
	if current_room != null:
		snapshot.battle_stats = current_room.battle_stats
	snapshot.timestamp = Time.get_unix_time_from_system() as int
	# 保存当前RNG状态
	snapshot.rng_seed = RNG.instance.seed
	snapshot.rng_state = RNG.instance.state
	return snapshot


func apply_to(
	character: CharacterStats,
	relic_handler: RelicHandler,
	potion_handler: PotionHandler = null
) -> void:
	if character == null:
		return
	character.health = health
	if character.deck != null and not deck_cards.is_empty():
		character.deck.cards = []
		for card in deck_cards:
			character.deck.cards.append(card.duplicate(true) as Card)
		for c: Card in character.deck.cards:
			c.sync_upgraded_flags()
	if relic_handler != null:
		var ids_to_restore := relic_ids
		if ids_to_restore.is_empty():
			push_warning("CombatSnapshot.apply_to: 快照中无 relic_ids，将跳过遗物恢复")
		else:
			var spent_apply := SaveGame.resolve_spent_relic_ids(spent_relic_ids)
			relic_handler.restore_relics_from_ids(ids_to_restore, false, true, spent_apply)
	if potion_handler != null:
		potion_handler.restore_from_ids(_normalize_potion_ids(potion_ids))
	# 恢复RNG状态，确保抽牌结果与第一次进入时相同
	RNG.set_from_save_data(rng_seed, rng_state)


static func _empty_potion_ids(slot_count: int = PotionHandler.DEFAULT_SLOTS) -> PackedStringArray:
	var out := PackedStringArray()
	var count := maxi(PotionHandler.DEFAULT_SLOTS, slot_count)
	out.resize(count)
	for i in range(count):
		out[i] = ""
	return out


static func _normalize_potion_ids(ids: PackedStringArray) -> PackedStringArray:
	var out := _empty_potion_ids(ids.size())
	for i in range(mini(out.size(), ids.size())):
		out[i] = String(ids[i])
	return out
