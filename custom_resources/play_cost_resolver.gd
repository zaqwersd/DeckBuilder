class_name PlayCostResolver
extends RefCounted

## 出牌费用唯一入口：固定费走修饰器与状态加费；X 费仅消耗当前能量。


static func compute_mana_to_spend(
	card: Card,
	char_stats: CharacterStats,
	combat_player: Node,
	player_modifiers: ModifierHandler
) -> int:
	if card == null or char_stats == null:
		return 0
	if card.is_x_cost():
		return char_stats.mana
	if card.is_unplayable():
		return card.cost
	if _has_card_free(combat_player):
		return 0
	var base := card.get_base_mana_cost()
	if player_modifiers:
		base = player_modifiers.get_modified_value(base, Modifier.Type.CARD_COST)
	base += _status_mana_cost_add(card, combat_player)
	if card.type == Card.Type.POWER and player_modifiers:
		base = player_modifiers.get_modified_value(base, Modifier.Type.POWER_CARD_COST)
	return maxi(0, base)


static func can_play(
	card: Card,
	char_stats: CharacterStats,
	effective_mana_cost: int = -1,
	combat_player: Node = null
) -> bool:
	if card == null or char_stats == null:
		return false
	if card.is_unplayable():
		return false
	if not card.meets_play_requirements(char_stats):
		return false
	var player := _resolve_combat_player(combat_player)
	if EntangledStatus.blocks_attack_card(card, player):
		return false
	return can_afford_mana(card, char_stats, effective_mana_cost)


static func _resolve_combat_player(combat_player: Node) -> Player:
	if combat_player is Player:
		return combat_player as Player
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group("player") as Player


## 仅判断能量是否足够，不检查 meets_play_requirements（手牌费用着色等）。
static func can_afford_mana(
	card: Card,
	char_stats: CharacterStats,
	effective_mana_cost: int = -1
) -> bool:
	if card == null or char_stats == null:
		return false
	if card.is_unplayable():
		return false
	if card.is_x_cost():
		return char_stats.mana >= 0
	var need := effective_mana_cost
	if need < 0:
		need = compute_mana_to_spend(card, char_stats, null, null)
	return char_stats.mana >= need


static func _status_mana_cost_add(card: Card, combat_player: Node) -> int:
	if card == null or card.is_x_cost() or card.type != Card.Type.ATTACK:
		return 0
	if combat_player == null or not (combat_player is Player):
		return 0
	return OverwhelmingStatus.stacks_on_player(combat_player as Player)


static func _has_card_free(combat_player: Node) -> bool:
	if combat_player == null or not (combat_player is Player):
		return false
	return CardFreeStatus.makes_next_card_free(combat_player as Player)
