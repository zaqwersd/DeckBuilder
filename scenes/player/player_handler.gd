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

## 回合末弃牌流程中：心流不立刻结算，在弃牌末尾统一抽牌；能量记到下一回合 `start_turn`。
var _defer_flow_for_eot_discard: bool = false
var _eot_flow_accum_draws: int = 0
var _eot_flow_accum_mana: int = 0
var _carry_mana_to_next_turn_start: int = 0


func _ready() -> void:
	Events.card_played.connect(_on_card_played)


## 洗牌与堆初始化（不含 start_turn）。须先于 `BattleUI.initialize_card_pile_ui()`，
## 否则首次抽牌时 `BattleCardFx.draw_pile_button` 为空 → 飞入动画被跳过。
func start_battle_prep(char_stats: CharacterStats) -> void:
	character = char_stats
	_intrinsic_draw_priority = true
	var raw_pile := character.deck.custom_duplicate()
	for c: Card in raw_pile.cards:
		c.sync_unlocked_intrinsic_flags_from_upgrade_tracks()
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
	if _carry_mana_to_next_turn_start != 0:
		character.mana += _carry_mana_to_next_turn_start
		_carry_mana_to_next_turn_start = 0
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
			character.add_card_to_exhaust(c)
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


func is_deferring_flow_for_end_turn_discard() -> bool:
	return _defer_flow_for_eot_discard


func accumulate_end_turn_flow_from_exhaust(draws: int, mana: int) -> void:
	_eot_flow_accum_draws += draws
	_eot_flow_accum_mana += mana


func _finish_discard_cards_defer() -> void:
	_defer_flow_for_eot_discard = false


func draw_cards(amount: int, is_start_of_turn_draw: bool = false, suppress_hand_enable: bool = false) -> void:
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
	if not suppress_hand_enable and not Events.is_combat_ended():
		hand.enable_hand()
	if is_start_of_turn_draw and not Events.is_combat_ended():
		Events.player_hand_drawn.emit()


func discard_cards() -> void:
	if Events.is_combat_ended():
		_sync_discard_entire_hand()
		Events.player_hand_discarded.emit()
		return

	if not is_instance_valid(hand) or hand.get_child_count() == 0:
		Events.player_hand_discarded.emit()
		return

	_defer_flow_for_eot_discard = true
	_eot_flow_accum_draws = 0
	_eot_flow_accum_mana = 0

	# 阶段 A：先弃光非虚无（入弃牌堆），再阶段 B 处理虚无（入消耗，触发心流累计）
	var pending_non: Array[Dictionary] = []
	for slot in hand.get_children():
		var card_ui_a := hand.get_card_ui_in_slot(slot)
		if card_ui_a and card_ui_a.card and not card_ui_a.card.ethereal:
			pending_non.append({
				"ui": card_ui_a,
				"card": card_ui_a.card,
				"from": card_ui_a.get_global_rect().get_center(),
			})

	if not pending_non.is_empty():
		if battle_card_fx and is_instance_valid(battle_card_fx) and is_instance_valid(player) and player.is_inside_tree():
			for i in range(pending_non.size()):
				var d0: Dictionary = pending_non[i]
				battle_card_fx.animate_discard_hand_end_turn(
					d0["ui"] as CardUI,
					HAND_SEQUENCE_STAGGER * float(i),
					true,
					d0["from"] as Vector2,
				)
			var max_discard_t := HAND_SEQUENCE_STAGGER * float(maxi(0, pending_non.size() - 1)) + BATTLE_DISCARD_ANIM_DURATION + 0.05
			if not Events.is_combat_ended():
				await get_tree().create_timer(max_discard_t).timeout

		if Events.is_combat_ended():
			_sync_discard_entire_hand()
			_eot_flow_accum_draws = 0
			_eot_flow_accum_mana = 0
			_finish_discard_cards_defer()
			Events.player_hand_discarded.emit()
			return

		for d1 in pending_non:
			var cui1 := d1["ui"] as CardUI
			var c1 := d1["card"] as Card
			if not is_instance_valid(cui1) or not c1:
				continue
			character.discard.add_card(c1)
			hand.discard_card(cui1)

	while true:
		if Events.is_combat_ended():
			_sync_discard_entire_hand()
			_eot_flow_accum_draws = 0
			_eot_flow_accum_mana = 0
			_finish_discard_cards_defer()
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
					character.add_card_to_exhaust(card_ui.card)
					hand.discard_card(card_ui)
				if Events.is_combat_ended():
					_sync_discard_entire_hand()
					_eot_flow_accum_draws = 0
					_eot_flow_accum_mana = 0
					_finish_discard_cards_defer()
					Events.player_hand_discarded.emit()
					return
				await get_tree().create_timer(HAND_ETH_DISCARD_INTERVAL).timeout
				break
		if not found_ethereal:
			break

	var has_any_card := false
	for slot in hand.get_children():
		if hand.get_card_ui_in_slot(slot):
			has_any_card = true
	if not has_any_card:
		for slot in hand.get_children():
			if is_instance_valid(slot):
				slot.queue_free()

	var pull := _eot_flow_accum_draws
	var mana_accum := _eot_flow_accum_mana
	_eot_flow_accum_draws = 0
	_eot_flow_accum_mana = 0
	_carry_mana_to_next_turn_start += mana_accum
	_finish_discard_cards_defer()

	if pull > 0 and not Events.is_combat_ended():
		await draw_cards(pull, false, true)

	if not Events.is_combat_ended():
		has_any_card = false
		for slot in hand.get_children():
			if hand.get_card_ui_in_slot(slot):
				has_any_card = true
		if not has_any_card:
			for slot in hand.get_children():
				if is_instance_valid(slot):
					slot.queue_free()

	print("[DEBUG] About to emit player_hand_discarded (normal path)")
	Events.player_hand_discarded.emit()
	print("[DEBUG] player_hand_discarded emitted (normal path)")


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
		if not card.defers_exhaust_to_end_of_play():
			character.add_card_to_exhaust(card)
		return
	if card.type == Card.Type.POWER:
		return
	# 延迟弃牌：普通技能/攻击牌现在由 Card.play() 在 apply_effects 完成后统一弃置
	# 避免卡牌在效果执行期间（如抽牌时）被洗回抽牌堆
	# 消耗牌和能力牌保持原有逻辑


func _on_statuses_applied(type: Status.Type) -> void:
	print("[DEBUG] _on_statuses_applied called, type: ", type)
	match type:
		Status.Type.START_OF_TURN:
			print("[DEBUG] START_OF_TURN - calling draw_cards")
			draw_cards(character.cards_per_turn, true)
		Status.Type.END_OF_TURN:
			print("[DEBUG] END_OF_TURN - calling discard_cards")
			discard_cards()


func _on_relics_activated(type: Relic.Type) -> void:
	print("[DEBUG] _on_relics_activated called, type: ", type)
	print("[DEBUG] player valid: ", is_instance_valid(player))
	if is_instance_valid(player):
		print("[DEBUG] status_handler valid: ", is_instance_valid(player.status_handler))
	
	if not is_instance_valid(player) or not is_instance_valid(player.status_handler):
		push_error("[DEBUG] Early return - player or status_handler invalid")
		return
	match type:
		Relic.Type.START_OF_TURN:
			player.status_handler.apply_statuses_by_type(Status.Type.START_OF_TURN)
		Relic.Type.END_OF_TURN:
			player.status_handler.apply_statuses_by_type(Status.Type.END_OF_TURN)
