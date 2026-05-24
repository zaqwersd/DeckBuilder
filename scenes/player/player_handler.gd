# Player turn order:
# 0. 激活敌人上回合挂上但未生效的状态（图标已显示）
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
const DRAW_CARD_SFX := preload("res://art/draw_card.ogg")

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
## 本场战斗是否已在首次 start_turn 抽牌前发放「战斗开始入手牌」类遗物牌。
var _battle_start_hand_cards_granted: bool = false


func _ready() -> void:
	Events.card_played.connect(_on_card_played)


## 洗牌与堆初始化（不含 start_turn）。须先于 `BattleUI.initialize_card_pile_ui()`，
## 否则首次抽牌时 `BattleCardFx.draw_pile_button` 为空 → 飞入动画被跳过。
func start_battle_prep(char_stats: CharacterStats) -> void:
	character = char_stats
	_battle_start_hand_cards_granted = false
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
	if is_instance_valid(player.status_handler):
		player.status_handler.activate_awaiting_statuses()
	if not _battle_start_hand_cards_granted:
		_battle_start_hand_cards_granted = true
		_grant_battle_start_hand_cards()
	relics.activate_relics_by_type(Relic.Type.START_OF_TURN)


func end_turn() -> void:
	hand.disable_hand()
	relics.activate_relics_by_type(Relic.Type.END_OF_TURN)


func get_hand_card_count() -> int:
	return _count_cards_in_hand()


func is_hand_full() -> bool:
	return get_hand_card_count() >= HAND_CARDS_MAX


## 尝试加入手牌；已满或已在手牌中则进入弃牌堆。返回 true 表示已进入手牌 UI。
## `insert_at_start`：插入手牌最左侧（战斗开始遗物牌等）。
func add_card_to_hand_or_discard(card: Card, insert_at_start: bool = false) -> bool:
	if card == null or not is_instance_valid(hand) or character == null:
		return false
	if hand.has_card_resource(card):
		return true
	if is_hand_full():
		character.discard.add_card(card)
		return false
	if insert_at_start:
		hand.add_card(card, 0)
	else:
		hand.add_card(card)
	return true


func _grant_battle_start_hand_cards() -> void:
	if not is_instance_valid(relics):
		return
	for relic: Relic in relics.get_all_relics():
		if relic == null:
			continue
		var card := relic.create_battle_start_hand_card()
		if card:
			add_card_to_hand_or_discard(card, true)


func _flush_drawn_cards_to_hand(drawn: Array[Card]) -> void:
	if not is_instance_valid(hand):
		return
	for c in drawn:
		if c:
			add_card_to_hand_or_discard(c)


func _flush_drawn_cards_to_discard(drawn: Array[Card]) -> void:
	if character == null:
		return
	for c in drawn:
		if c:
			character.discard.add_card(c)


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
		elif not c.retains:
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


func _play_draw_card_sfx(index: int) -> void:
	var delay := HAND_SEQUENCE_STAGGER * float(index)
	if delay <= 0.0:
		SFXPlayer.play(DRAW_CARD_SFX)
		return
	var tree := get_tree()
	if tree == null:
		SFXPlayer.play(DRAW_CARD_SFX)
		return
	var timer := tree.create_timer(delay)
	timer.timeout.connect(func() -> void: SFXPlayer.play(DRAW_CARD_SFX), CONNECT_ONE_SHOT)


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
	amount = maxi(0, amount)
	var to_hand: Array[Card] = []
	var to_discard: Array[Card] = []
	var pending_hand_count := _count_cards_in_hand()
	var drawn_sfx_index := 0
	for _i in range(amount):
		if Events.is_combat_ended():
			_flush_drawn_cards_to_hand(to_hand)
			_flush_drawn_cards_to_discard(to_discard)
			return
		## 仅在本次仍需抽牌且抽牌堆已空时，才将弃牌堆洗入抽牌堆
		reshuffle_deck_from_discard()
		if character.draw_pile.empty():
			break
		var c := _pop_draw_card()
		_play_draw_card_sfx(drawn_sfx_index)
		drawn_sfx_index += 1
		if pending_hand_count >= HAND_CARDS_MAX:
			to_discard.append(c)
		else:
			to_hand.append(c)
			pending_hand_count += 1

	if Events.is_combat_ended():
		_flush_drawn_cards_to_hand(to_hand)
		_flush_drawn_cards_to_discard(to_discard)
		if is_start_of_turn_draw:
			Events.player_hand_drawn.emit()
		return

	if battle_card_fx and is_instance_valid(battle_card_fx):
		for i in range(to_hand.size()):
			var delay := HAND_SEQUENCE_STAGGER * float(i)
			battle_card_fx.animate_draw_to_hand(to_hand[i], hand, delay)
		for i in range(to_discard.size()):
			var delay := HAND_SEQUENCE_STAGGER * float(i)
			battle_card_fx.animate_draw_to_discard(to_discard[i], delay)
		var max_n := maxi(to_hand.size(), to_discard.size())
		var max_t := HAND_SEQUENCE_STAGGER * float(maxi(0, max_n - 1)) + BATTLE_DRAW_ANIM_DURATION + 0.05
		await get_tree().create_timer(max_t).timeout
		_flush_drawn_cards_to_hand(to_hand)
		_flush_drawn_cards_to_discard(to_discard)
	else:
		for c in to_hand:
			if Events.is_combat_ended():
				break
			add_card_to_hand_or_discard(c)
		_flush_drawn_cards_to_discard(to_discard)

	if not is_instance_valid(hand):
		return
	if not suppress_hand_enable and not Events.is_combat_ended():
		hand.enable_hand()
	if is_start_of_turn_draw and not Events.is_combat_ended():
		Events.player_hand_drawn.emit()


func discard_cards() -> void:
	if Events.is_combat_ended():
		_sync_discard_entire_hand()
		_emit_player_hand_discarded_after_layout()
		return

	if not is_instance_valid(hand) or hand.get_child_count() == 0:
		_emit_player_hand_discarded_after_layout()
		return

	_defer_flow_for_eot_discard = true
	_eot_flow_accum_draws = 0
	_eot_flow_accum_mana = 0

	# 阶段 A：先弃光非虚无（入弃牌堆），再阶段 B 处理虚无（入消耗，触发心流累计）
	var pending_non: Array[Dictionary] = []
	for slot in hand.get_children():
		var card_ui_a := hand.get_card_ui_in_slot(slot)
		if card_ui_a and card_ui_a.card and not card_ui_a.card.ethereal and not card_ui_a.card.retains:
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
			_emit_player_hand_discarded_after_layout()
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
			_emit_player_hand_discarded_after_layout()
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
					_emit_player_hand_discarded_after_layout()
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
	_emit_player_hand_discarded_after_layout()
	print("[DEBUG] player_hand_discarded emitted (normal path)")


func _emit_player_hand_discarded_after_layout() -> void:
	if is_instance_valid(hand):
		hand.finalize_end_turn_hand_layout()
	Events.player_hand_discarded.emit()


## 抽牌堆已空且弃牌堆有牌时，将弃牌堆洗入抽牌堆。仅应在「即将抽牌」时调用。
func reshuffle_deck_from_discard() -> void:
	if not character.draw_pile.empty():
		return
	if character.discard.empty():
		return
	while not character.discard.empty():
		character.draw_pile.add_card(character.discard.draw_card())

	character.draw_pile.shuffle()
	_intrinsic_draw_priority = false
	Events.deck_shuffled.emit()


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
