class_name CharacterStats
extends Stats

@export_group("Visuals")
@export var character_name: String
@export_multiline var description: String
@export var portrait: Texture
## 与 Relic.CharacterType 键名（小写）对应，用于 can_appear_as_reward；留空则回退为 character_name
@export var relic_match_id: String = ""

@export_group("Gameplay Data")
@export var starting_deck: CardPile
## 商店与战后「选一张新卡」的候选池（刀锋在 `blade.tres` 里指向 `blade_draftable_cards.tres`）。
@export var draftable_cards: CardPile
@export var cards_per_turn: int = 5
@export var max_mana: int
@export var starting_relic: Relic

var mana: int : set = set_mana
var deck: CardPile
var discard: CardPile
var draw_pile: CardPile
## 本场战斗中因打出消耗、虚无、效果等离开循环的牌
var exhaust: CardPile


func set_mana(value: int) -> void:
	mana = value
	stats_changed.emit()


func reset_mana() -> void:
	mana = max_mana


func take_damage(damage: int) -> void:
	var initial_health := health
	super.take_damage(damage)
	if initial_health > health:
		Events.player_hit.emit()


func can_play_card(card: Card) -> bool:
	if card.cost < 0:
		return false
	return mana >= card.cost


func create_instance() -> Resource:
	var instance: CharacterStats = self.duplicate()
	instance.health = max_health
	instance.block = 0
	instance.reset_mana()
	instance.deck = instance.starting_deck.duplicate()
	instance.draw_pile = CardPile.new()
	instance.discard = CardPile.new()
	instance.exhaust = CardPile.new()
	return instance
