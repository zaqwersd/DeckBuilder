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
	var base := card.get_base_mana_cost()
	if player_modifiers:
		base = player_modifiers.get_modified_value(base, Modifier.Type.CARD_COST)
	base += _status_mana_cost_add(card, combat_player)
	return base


static func can_play(
	card: Card,
	char_stats: CharacterStats,
	effective_mana_cost: int = -1
) -> bool:
	if card == null or char_stats == null:
		return false
	if card.is_unplayable():
		return false
	if not card.meets_play_requirements(char_stats):
		return false
	return can_afford_mana(card, char_stats, effective_mana_cost)


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
