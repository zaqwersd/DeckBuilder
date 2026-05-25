class_name CombatSnapshot
extends Resource

## 战斗开始时的状态快照，用于中途退出后重进时恢复

@export var health: int
@export var deck_cards: Array[Card]
## 保存遗物ID而不是Resource引用，避免Resource失效问题
@export var relic_ids: PackedStringArray
## 进战瞬间的失效状态（仅 create_from 写入；战斗中途保存不修改，读档回退到此）
@export var spent_relic_ids: PackedStringArray = PackedStringArray()
@export var room: Room
@export var timestamp: int
## 进入战斗时的RNG状态，确保重进后抽牌结果相同
@export var rng_seed: int
@export var rng_state: int
## 影武士四回合循环（3 攻击随机序 + 强化）的 RNG 洗牌结果；读档回到战斗开始时，步进从第 1 个意图开始。
@export var shadow_samurai_cycle_slots: PackedInt32Array = PackedInt32Array()


func has_shadow_samurai_cycle() -> bool:
	return shadow_samurai_cycle_slots.size() == 4

static func create_from(character: CharacterStats, current_relics: Array[Relic], current_room: Room) -> CombatSnapshot:
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
	
	snapshot.room = current_room
	snapshot.timestamp = Time.get_unix_time_from_system() as int
	# 保存当前RNG状态
	snapshot.rng_seed = RNG.instance.seed
	snapshot.rng_state = RNG.instance.state
	return snapshot


func apply_to(character: CharacterStats, relic_handler: RelicHandler) -> void:
	if character == null:
		return
	character.health = health
	if character.deck != null and not deck_cards.is_empty():
		character.deck.cards = []
		for card in deck_cards:
			character.deck.cards.append(card.duplicate(true) as Card)
		for c: Card in character.deck.cards:
			c.sync_unlocked_intrinsic_flags_from_upgrade_tracks()
	if relic_handler != null:
		var ids_to_restore := relic_ids
		if ids_to_restore.is_empty():
			push_warning("CombatSnapshot.apply_to: 快照中无 relic_ids，将跳过遗物恢复")
		else:
			var spent_apply := SaveGame.resolve_spent_relic_ids(spent_relic_ids)
			relic_handler.restore_relics_from_ids(ids_to_restore, false, true, spent_apply)
	# 恢复RNG状态，确保抽牌结果与第一次进入时相同
	RNG.set_from_save_data(rng_seed, rng_state)
