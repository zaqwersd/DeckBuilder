# Player turn order:
# 1. START_OF_TURN Relics 
# 2. START_OF_TURN Statuses
# 3. Draw Hand
# 4. End Turn 
# 5. END_OF_TURN Relics 
# 6. END_OF_TURN Statuses
# 7. Discard Hand
class_name PlayerHandler
extends Node

## 多张牌并行飞入/飞出时，从左到右每条动画起点错开的时间（秒）
const HAND_SEQUENCE_STAGGER := 0.05
## 虚无牌仍逐个处理时的间隔（可与弃牌主批次并行风格分开）
const HAND_ETH_DISCARD_INTERVAL := 0.12
## 与 BattleCardFx 中动画时长一致（不在此脚本引用 class_name，避免解析顺序报错）
const BATTLE_DRAW_ANIM_DURATION := 0.26
const BATTLE_DISCARD_ANIM_DURATION := 0.24

@export var relics: RelicHandler
@export var player: Player
@export var hand: Hand
@export var battle_card_fx: Node

var character: CharacterStats


func _ready() -> void:
	Events.card_played.connect(_on_card_played)


## 洗牌与堆初始化（不含 start_turn）。须先于 `BattleUI.initialize_card_pile_ui()`，
## 否则首次抽牌时 `BattleCardFx.draw_pile_button` 为空 → 飞入动画被跳过。
func start_battle_prep(char_stats: CharacterStats) -> void:
	character = char_stats
	character.draw_pile = character.deck.custom_duplicate()
	character.draw_pile.shuffle()
	character.discard = CardPile.new()
	if not relics.relics_activated.is_connected(_on_relics_activated):
		relics.relics_activated.connect(_on_relics_activated)
	if not player.status_handler.statuses_applied.is_connected(_on_statuses_applied):
		player.status_handler.statuses_applied.connect(_on_statuses_applied)


func start_battle(char_stats: CharacterStats) -> void:
	start_battle_prep(char_stats)
	start_turn()


func start_turn() -> void:
	character.block = 0
	character.reset_mana()
	relics.activate_relics_by_type(Relic.Type.START_OF_TURN)


func end_turn() -> void:
	hand.disable_hand()
	relics.activate_relics_by_type(Relic.Type.END_OF_TURN)


func draw_cards(amount: int, is_start_of_turn_draw: bool = false) -> void:
	var drawn_cards: Array[Card] = []
	for _i in range(amount):
		reshuffle_deck_from_discard()
		drawn_cards.append(character.draw_pile.draw_card())
		reshuffle_deck_from_discard()

	if battle_card_fx and is_instance_valid(battle_card_fx):
		for i in range(drawn_cards.size()):
			var delay := HAND_SEQUENCE_STAGGER * float(i)
			battle_card_fx.animate_draw_to_hand(drawn_cards[i], hand, player.modifier_handler, delay)
		var max_t := HAND_SEQUENCE_STAGGER * float(maxi(0, drawn_cards.size() - 1)) + BATTLE_DRAW_ANIM_DURATION + 0.05
		await get_tree().create_timer(max_t).timeout
	else:
		for c in drawn_cards:
			hand.add_card(c)

	hand.enable_hand()
	if is_start_of_turn_draw:
		Events.player_hand_drawn.emit()


func discard_cards() -> void:
	if hand.get_child_count() == 0:
		Events.player_hand_discarded.emit()
		return

	# 先结算虚无（ethereal）：全部移出手牌且不进入弃牌堆，再处理其余牌的弃牌动画与入堆
	while true:
		var found_ethereal := false
		for slot in hand.get_children():
			var card_ui := hand.get_card_ui_in_slot(slot)
			if card_ui and card_ui.card and card_ui.card.ethereal:
				found_ethereal = true
				if battle_card_fx and is_instance_valid(battle_card_fx) and battle_card_fx.has_method("animate_ethereal_vanish"):
					await battle_card_fx.animate_ethereal_vanish(hand, card_ui, player.modifier_handler)
				else:
					hand.discard_card(card_ui)
				await get_tree().create_timer(HAND_ETH_DISCARD_INTERVAL).timeout
				break
		if not found_ethereal:
			break

	var pending: Array[Dictionary] = []
	for slot in hand.get_children():
		var card_ui := hand.get_card_ui_in_slot(slot)
		if card_ui and card_ui.card:
			pending.append({
				"ui": card_ui,
				"card": card_ui.card,
				"from": card_ui.get_global_rect().get_center(),
			})

	if pending.is_empty():
		for slot in hand.get_children():
			if is_instance_valid(slot):
				slot.queue_free()
		Events.player_hand_discarded.emit()
		return

	if battle_card_fx and is_instance_valid(battle_card_fx):
		for i in range(pending.size()):
			var d: Dictionary = pending[i]
			battle_card_fx.animate_discard_hand_end_turn(
				d["ui"] as CardUI,
				player.modifier_handler,
				HAND_SEQUENCE_STAGGER * float(i),
				true,
				d["from"] as Vector2,
			)
		var max_discard_t := HAND_SEQUENCE_STAGGER * float(maxi(0, pending.size() - 1)) + BATTLE_DISCARD_ANIM_DURATION + 0.05
		await get_tree().create_timer(max_discard_t).timeout

	for d in pending:
		character.discard.add_card(d["card"] as Card)
		hand.discard_card(d["ui"] as CardUI)

	Events.player_hand_discarded.emit()


func reshuffle_deck_from_discard() -> void:
	if not character.draw_pile.empty():
		return

	while not character.discard.empty():
		character.draw_pile.add_card(character.discard.draw_card())

	character.draw_pile.shuffle()


func _on_card_played(card: Card) -> void:
	if card.exhausts or card.type == Card.Type.POWER:
		return
	
	character.discard.add_card(card)


func _on_statuses_applied(type: Status.Type) -> void:
	match type:
		Status.Type.START_OF_TURN:
			draw_cards(character.cards_per_turn, true)
		Status.Type.END_OF_TURN:
			discard_cards()


func _on_relics_activated(type: Relic.Type) -> void:
	match type:
		Relic.Type.START_OF_TURN:
			player.status_handler.apply_statuses_by_type(Status.Type.START_OF_TURN)
		Relic.Type.END_OF_TURN:
			player.status_handler.apply_statuses_by_type(Status.Type.END_OF_TURN)
