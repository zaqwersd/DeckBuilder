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
## 固有牌与首回合抽牌：手牌张数上限（与固有「填满手牌」规则一致）
const HAND_CARDS_MAX := 10

@export var relics: RelicHandler
@export var player: Player
@export var hand: Hand
@export var battle_card_fx: Node

var character: CharacterStats
## 本场战斗中，弃牌堆尚未洗回抽牌堆时：每次抽牌优先抽到「固有」牌；洗牌后与普通牌无异。
var _intrinsic_draw_priority: bool = true


func _ready() -> void:
	Events.card_played.connect(_on_card_played)


## 洗牌与堆初始化（不含 start_turn）。须先于 `BattleUI.initialize_card_pile_ui()`，
## 否则首次抽牌时 `BattleCardFx.draw_pile_button` 为空 → 飞入动画被跳过。
func start_battle_prep(char_stats: CharacterStats) -> void:
	character = char_stats
	_intrinsic_draw_priority = true
	var raw_pile := character.deck.custom_duplicate()
	var intr: Array[Card] = []
	var rest: Array[Card] = []
	for c: Card in raw_pile.cards:
		if c.intrinsic:
			print("[PlayerHandler] 固有卡牌: %s (intrinsic=%s)" % [c.card_name, c.intrinsic])
			intr.append(c)
		else:
			rest.append(c)
	print("[PlayerHandler] 固有卡牌数量: %d, 普通卡牌: %d" % [intr.size(), rest.size()])
	RNG.array_shuffle(intr)
	RNG.array_shuffle(rest)
	character.draw_pile = CardPile.new()
	character.draw_pile.cards.append_array(intr)
	character.draw_pile.cards.append_array(rest)
	character.draw_pile.card_pile_size_changed.emit(character.draw_pile.cards.size())
	character.discard = CardPile.new()
	character.exhaust = CardPile.new()
	if not relics.relics_activated.is_connected(_on_relics_activated):
		relics.relics_activated.connect(_on_relics_activated)
	if not player.status_handler.statuses_applied.is_connected(_on_statuses_applied):
		player.status_handler.statuses_applied.connect(_on_statuses_applied)


func start_battle(char_stats: CharacterStats) -> void:
	start_battle_prep(char_stats)
	start_turn()


func start_turn() -> void:
	if Events.is_combat_ended():
		return
	if not is_instance_valid(player) or not is_instance_valid(player.status_handler):
		return
	character.block = 0
	character.reset_mana()
	relics.activate_relics_by_type(Relic.Type.START_OF_TURN)


func end_turn() -> void:
	hand.disable_hand()
	relics.activate_relics_by_type(Relic.Type.END_OF_TURN)


func _flush_drawn_cards_to_hand(drawn: Array[Card]) -> void:
	if not is_instance_valid(hand):
		return
	for c in drawn:
		if c and not hand.has_card_resource(c):
			hand.add_card(c)


func _sync_discard_entire_hand() -> void:
	if not is_instance_valid(hand):
		return
	var uis: Array[CardUI] = []
	for slot in hand.get_children():
		var cui := hand.get_card_ui_in_slot(slot)
		if cui and cui.card:
			uis.append(cui)
	for cui in uis:
		if not is_instance_valid(cui) or not cui.card:
			continue
		var c: Card = cui.card
		if c.ethereal:
			if character.exhaust:
				character.exhaust.add_card(c)
			hand.discard_card(cui)
		else:
			character.discard.add_card(c)
			hand.discard_card(cui)


func _count_cards_in_hand() -> int:
	if not is_instance_valid(hand):
		return 0
	var n := 0
	for slot in hand.get_children():
		var cui := hand.get_card_ui_in_slot(slot)
		if cui and cui.card:
			n += 1
	return n


func _pop_draw_card() -> Card:
	if _intrinsic_draw_priority:
		var cards := character.draw_pile.cards
		for i in range(cards.size()):
			var c: Card = cards[i]
			if c and c.intrinsic:
				return character.draw_pile.remove_card_at(i)
	return character.draw_pile.draw_card()


func draw_cards(amount: int, is_start_of_turn_draw: bool = false) -> void:
	if Events.is_combat_ended():
		return
	var space := HAND_CARDS_MAX - _count_cards_in_hand()
	amount = clampi(amount, 0, maxi(0, space))
	var drawn_cards: Array[Card] = []
	for _i in range(amount):
		if Events.is_combat_ended():
			_flush_drawn_cards_to_hand(drawn_cards)
			return
		reshuffle_deck_from_discard()
		if character.draw_pile.empty():
			break
		drawn_cards.append(_pop_draw_card())
		reshuffle_deck_from_discard()

	if Events.is_combat_ended():
		_flush_drawn_cards_to_hand(drawn_cards)
		if is_start_of_turn_draw:
			Events.player_hand_drawn.emit()
		return

	if battle_card_fx and is_instance_valid(battle_card_fx):
		for i in range(drawn_cards.size()):
			var delay := HAND_SEQUENCE_STAGGER * float(i)
			battle_card_fx.animate_draw_to_hand(drawn_cards[i], hand, delay)
		var max_t := HAND_SEQUENCE_STAGGER * float(maxi(0, drawn_cards.size() - 1)) + BATTLE_DRAW_ANIM_DURATION + 0.05
		await get_tree().create_timer(max_t).timeout
		_flush_drawn_cards_to_hand(drawn_cards)
	else:
		for c in drawn_cards:
			if Events.is_combat_ended():
				break
			if is_instance_valid(hand) and not hand.has_card_resource(c):
				hand.add_card(c)

	if not is_instance_valid(hand):
		return
	if not Events.is_combat_ended():
		hand.enable_hand()
	if is_start_of_turn_draw and not Events.is_combat_ended():
		Events.player_hand_drawn.emit()


func discard_cards() -> void:
	if Events.is_combat_ended():
		_sync_discard_entire_hand()
		Events.player_hand_discarded.emit()
		return

	if hand.get_child_count() == 0:
		Events.player_hand_discarded.emit()
		return

	# 先结算虚无（ethereal）：全部移出手牌且不进入弃牌堆，再处理其余牌的弃牌动画与入堆
	while true:
		if Events.is_combat_ended():
			_sync_discard_entire_hand()
			Events.player_hand_discarded.emit()
			return
		var found_ethereal := false
		for slot in hand.get_children():
			var card_ui := hand.get_card_ui_in_slot(slot)
			if card_ui and card_ui.card and card_ui.card.ethereal:
				found_ethereal = true
				if battle_card_fx and is_instance_valid(battle_card_fx) and battle_card_fx.has_method("animate_ethereal_vanish"):
					await battle_card_fx.animate_ethereal_vanish(hand, card_ui)
				else:
					hand.discard_card(card_ui)
				if Events.is_combat_ended():
					_sync_discard_entire_hand()
					Events.player_hand_discarded.emit()
					return
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

	if Events.is_combat_ended():
		for d in pending:
			var cui := d["ui"] as CardUI
			var c := d["card"] as Card
			if not is_instance_valid(cui) or not c:
				continue
			if c.ethereal:
				if character.exhaust:
					character.exhaust.add_card(c)
				hand.discard_card(cui)
			else:
				character.discard.add_card(c)
				hand.discard_card(cui)
		Events.player_hand_discarded.emit()
		return

	if battle_card_fx and is_instance_valid(battle_card_fx) and is_instance_valid(player) and player.is_inside_tree():
		for i in range(pending.size()):
			var d: Dictionary = pending[i]
			battle_card_fx.animate_discard_hand_end_turn(
				d["ui"] as CardUI,
				HAND_SEQUENCE_STAGGER * float(i),
				true,
				d["from"] as Vector2,
			)
		var max_discard_t := HAND_SEQUENCE_STAGGER * float(maxi(0, pending.size() - 1)) + BATTLE_DISCARD_ANIM_DURATION + 0.05
		if not Events.is_combat_ended():
			await get_tree().create_timer(max_discard_t).timeout

	for d in pending:
		var cui2 := d["ui"] as CardUI
		var c2 := d["card"] as Card
		if not is_instance_valid(cui2) or not c2:
			continue
		character.discard.add_card(c2)
		hand.discard_card(cui2)

	Events.player_hand_discarded.emit()


func reshuffle_deck_from_discard() -> void:
	if not character.draw_pile.empty():
		return
	if character.discard.empty():
		return
	while not character.discard.empty():
		character.draw_pile.add_card(character.discard.draw_card())

	character.draw_pile.shuffle()
	_intrinsic_draw_priority = false


func _on_card_played(card: Card) -> void:
	if card.exhausts:
		if character.exhaust:
			character.exhaust.add_card(card)
		return
	if card.type == Card.Type.POWER:
		return
	# 故障机器等：同一张 Card 资源第二次「视为打出」时不应再次入弃牌堆
	if character.discard.cards.has(card):
		return
	character.discard.add_card(card)


func _on_statuses_applied(type: Status.Type) -> void:
	match type:
		Status.Type.START_OF_TURN:
			draw_cards(character.cards_per_turn, true)
		Status.Type.END_OF_TURN:
			discard_cards()


func _on_relics_activated(type: Relic.Type) -> void:
	if not is_instance_valid(player) or not is_instance_valid(player.status_handler):
		return
	match type:
		Relic.Type.START_OF_TURN:
			player.status_handler.apply_statuses_by_type(Status.Type.START_OF_TURN)
		Relic.Type.END_OF_TURN:
			player.status_handler.apply_statuses_by_type(Status.Type.END_OF_TURN)
