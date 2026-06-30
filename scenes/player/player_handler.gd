# 玩家回合开始（PlayerHandler._run_player_turn_start_pipeline 统一编排）：
# 0. 恢复敌人硬壳（须先于所有回合开始效果）
# 0b. 敌人多层护甲：按层数获得格挡（玩家回合开始）
# 1. 重置格挡 / 能量
# 2. 激活上回合挂上、本回合才生效的状态（易伤、缠身等）
# 3. 战斗开始入手牌类遗物（仅首场一次）
# 4. START_OF_TURN 遗物
# 5. START_OF_TURN 状态 tick（扣回合、易伤到期等）
# 6. 显示敌人意图
# 7. 刷新手牌战斗数字 → 抽牌
#
# 玩家回合进行中：打牌 → End Turn
# END_OF_TURN 遗物 → END_OF_TURN 状态 → 弃牌
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

## 本场战斗是否已在首次 start_turn 抽牌前发放「战斗开始入手牌」类遗物牌。
var _battle_start_hand_cards_granted: bool = false
## 本场战斗的首个玩家回合：回合开始遗物无间隔触发，减轻进战卡顿感。
var _first_turn_of_battle: bool = true
## 本次 draw_cards 批次内洗牌触发的额外抽牌（如莫比乌斯环），须在 draw_cards 返回前全部结算。
var _shuffle_bonus_draws_pending: int = 0
## 出牌协程期间延迟播放的「飞入抽牌堆」动画（由 draw_pile_insert_animation_requested 入队）。
var _deferred_draw_pile_insert_anims: Array[Card] = []
## player_drew_cards 同步回调期间入队的即时飞入动画，由 draw_cards 批次在抽牌飞行动画前播放。
var _immediate_draw_pile_insert_anims: Array[Card] = []


func _ready() -> void:
	Events.card_played.connect(_on_card_played)
	if not Events.draw_pile_insert_animation_requested.is_connected(_on_draw_pile_insert_animation_requested):
		Events.draw_pile_insert_animation_requested.connect(_on_draw_pile_insert_animation_requested)


## 洗牌与堆初始化（不含 start_turn）。须先于 `BattleUI.initialize_card_pile_ui()`，
## 否则首次抽牌时 `BattleCardFx.draw_pile_button` 为空 → 飞入动画被跳过。
## combat_reload：战斗读档时跳过洗牌，从 combat_snapshot 恢复 setup 后的牌堆顺序。
func start_battle_prep(char_stats: CharacterStats, combat_reload: bool = false) -> void:
	character = char_stats
	_battle_start_hand_cards_granted = false
	_first_turn_of_battle = true
	_shuffle_bonus_draws_pending = 0
	_deferred_draw_pile_insert_anims.clear()
	_immediate_draw_pile_insert_anims.clear()
	_intrinsic_draw_priority = true
	if combat_reload and _try_restore_piles_from_combat_snapshot():
		pass
	else:
		if combat_reload:
			push_warning("PlayerHandler: 战斗读档缺少 setup 牌堆快照，回退为重新洗牌")
		_build_fresh_combat_piles_from_deck()
	if not relics.relics_activated.is_connected(_on_relics_activated):
		relics.relics_activated.connect(_on_relics_activated)
	if not player.status_handler.statuses_applied.is_connected(_on_statuses_applied):
		player.status_handler.statuses_applied.connect(_on_statuses_applied)


func _build_fresh_combat_piles_from_deck() -> void:
	var raw_pile := character.deck.custom_duplicate()
	var intr: Array[Card] = []
	var rest: Array[Card] = []
	for c: Card in raw_pile.cards:
		c.sync_upgraded_flags()
		if c.intrinsic:
			intr.append(c)
		else:
			rest.append(c)
	RNG.array_shuffle(intr)
	RNG.array_shuffle(rest)
	character.draw_pile = CardPile.new()
	character.draw_pile.cards.append_array(intr)
	character.draw_pile.cards.append_array(rest)
	character.draw_pile.card_pile_size_changed.emit(character.draw_pile.cards.size())
	character.discard = CardPile.new()
	character.exhaust = CardPile.new()


func _try_restore_piles_from_combat_snapshot() -> bool:
	var run := get_tree().get_first_node_in_group("run")
	if run == null:
		return false
	var save_data: SaveGame = run.get("save_data") as SaveGame
	if save_data == null or save_data.combat_snapshot == null:
		return false
	return save_data.combat_snapshot.restore_battle_piles(character)


func start_battle(char_stats: CharacterStats) -> void:
	start_battle_prep(char_stats)
	start_turn()


func start_turn() -> void:
	_flush_deferred_end_turn_mana()
	if Events.is_combat_ended():
		Events.end_player_turn_start_resolving()
		return
	if not is_instance_valid(player) or not is_instance_valid(player.status_handler):
		Events.end_player_turn_start_resolving()
		return
	
	Events.begin_player_turn_start_resolving()
	HardShellStatus.restore_all_in_tree(get_tree())
	LayeredArmorStatus.grant_block_all_in_tree(get_tree())
	
	# 1. 重置格挡 / 能量
	character.block = 0
	character.reset_mana()
	
	# 2. 激活待生效状态（须先于 START_OF_TURN tick，配合 skip_next_start_of_turn_tick）
	player.status_handler.activate_awaiting_statuses()
	
	# 3. 战斗开始入手牌（仅首场一次）
	if not _battle_start_hand_cards_granted:
		_battle_start_hand_cards_granted = true
		_grant_battle_start_hand_cards()
	
	if Events.is_combat_ended():
		Events.end_player_turn_start_resolving()
		return
	
	# 4. 回合开始遗物 → 5. START_OF_TURN tick（由信号链接，见 _on_relics_activated / _on_statuses_applied）
	var instant_relics := _first_turn_of_battle
	_first_turn_of_battle = false
	if is_instance_valid(relics):
		relics.activate_relics_by_type(Relic.Type.START_OF_TURN, instant_relics)
	else:
		player.status_handler.apply_statuses_by_type(Status.Type.START_OF_TURN)


## 阶段 5 完成后：同步修饰器 → 显示意图 → 刷新手牌 → 抽牌。
func _finish_player_turn_start_setup() -> void:
	if Events.is_combat_ended():
		Events.end_player_turn_start_resolving()
		return
	player.status_handler.prepare_combat_context_for_intent()
	Events.player_turn_intent_context_ready.emit()
	Events.player_combat_stat_context_changed.emit()
	Events.end_player_turn_start_resolving()
	draw_cards(character.cards_per_turn, true)
	await _flush_deferred_end_turn_draws()


func _flush_deferred_end_turn_mana() -> void:
	var amount := Events.consume_deferred_end_turn_mana()
	if amount > 0:
		character.mana += amount


func _flush_deferred_end_turn_draws() -> void:
	var amount := Events.consume_deferred_end_turn_draw()
	if amount > 0:
		await draw_cards(amount, false, false, true)


func end_turn() -> void:
	Events.begin_player_turn_end_resolving()
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


## 洗牌遗物等：将额外抽牌记入当前 draw_cards，在整次抽牌（含动画）结束后再抽，避免打出牌已入弃牌堆才补抽。
func request_shuffle_bonus_draw(amount: int = 1) -> void:
	_shuffle_bonus_draws_pending += maxi(0, amount)


func draw_cards(
	amount: int,
	is_start_of_turn_draw: bool = false,
	suppress_hand_enable: bool = false,
	defer_side_animations: bool = false
) -> void:
	if Events.is_combat_ended():
		return
	await _draw_cards_batch(amount, is_start_of_turn_draw, suppress_hand_enable, defer_side_animations)
	await _flush_shuffle_bonus_draws(suppress_hand_enable, defer_side_animations)


func _flush_shuffle_bonus_draws(suppress_hand_enable: bool, defer_side_animations: bool) -> void:
	while _shuffle_bonus_draws_pending > 0:
		if Events.is_combat_ended():
			_shuffle_bonus_draws_pending = 0
			return
		_shuffle_bonus_draws_pending -= 1
		await _draw_cards_batch(1, false, suppress_hand_enable, defer_side_animations)


func _draw_cards_batch(
	amount: int,
	is_start_of_turn_draw: bool = false,
	suppress_hand_enable: bool = false,
	defer_side_animations: bool = false
) -> void:
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

	var drawn_count := to_hand.size() + to_discard.size()
	_notify_player_drew_cards(drawn_count, defer_side_animations)
	await _flush_immediate_draw_pile_insert_anims()

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


func _notify_player_drew_cards(count: int, defer_side_animations: bool) -> void:
	if count <= 0 or player == null:
		return
	Events.player_drew_cards.emit(player, count, defer_side_animations)


func _on_draw_pile_insert_animation_requested(card: Card, defer_animation: bool) -> void:
	if card == null:
		return
	if defer_animation:
		_deferred_draw_pile_insert_anims.append(card)
	else:
		_immediate_draw_pile_insert_anims.append(card)


func _flush_immediate_draw_pile_insert_anims() -> void:
	while not _immediate_draw_pile_insert_anims.is_empty():
		if Events.is_combat_ended():
			_immediate_draw_pile_insert_anims.clear()
			return
		var card: Card = _immediate_draw_pile_insert_anims.pop_front()
		await _play_draw_pile_insert_animation(card)


func play_draw_pile_insert_animations(cards: Array[Card]) -> void:
	for card in cards:
		if card == null or Events.is_combat_ended():
			return
		await _play_draw_pile_insert_animation(card)


func flush_deferred_draw_pile_insert_animations() -> void:
	if _deferred_draw_pile_insert_anims.is_empty():
		return
	var batch := _deferred_draw_pile_insert_anims.duplicate()
	_deferred_draw_pile_insert_anims.clear()
	await play_draw_pile_insert_animations(batch)


func _play_draw_pile_insert_animation(card: Card) -> void:
	if card == null or Events.is_combat_ended():
		return
	if battle_card_fx == null or not is_instance_valid(battle_card_fx):
		return
	if not battle_card_fx.has_method("animate_inserted_card_flying_to_draw_pile"):
		return
	await battle_card_fx.animate_inserted_card_flying_to_draw_pile(card)


func _trigger_end_turn_card_effect(card_ui: CardUI) -> void:
	if card_ui == null or not is_instance_valid(card_ui) or card_ui.card == null:
		return
	if is_instance_valid(player):
		await card_ui.card.on_end_turn_in_hand(player, self, card_ui)


func discard_cards() -> void:
	if Events.is_combat_ended():
		_sync_discard_entire_hand()
		_emit_player_hand_discarded_after_layout()
		return

	if not is_instance_valid(hand) or hand.get_child_count() == 0:
		_emit_player_hand_discarded_after_layout()
		return

	# 阶段 A：先弃光非虚无（入弃牌堆），再阶段 B 处理虚无（入消耗堆）
	var pending_non: Array[Dictionary] = []
	for slot in hand.get_children():
		var card_ui_a := hand.get_card_ui_in_slot(slot)
		if card_ui_a and card_ui_a.card and not card_ui_a.card.ethereal and not card_ui_a.card.retains:
			await _trigger_end_turn_card_effect(card_ui_a)
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

	if not Events.is_combat_ended():
		has_any_card = false
		for slot in hand.get_children():
			if hand.get_card_ui_in_slot(slot):
				has_any_card = true
		if not has_any_card:
			for slot in hand.get_children():
				if is_instance_valid(slot):
					slot.queue_free()

	_emit_player_hand_discarded_after_layout()


func _emit_player_hand_discarded_after_layout() -> void:
	if is_instance_valid(hand):
		hand.finalize_end_turn_hand_layout()
	Events.end_player_turn_end_resolving()
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
	if card.is_replaying_effects_without_payment():
		return
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
	match type:
		Status.Type.START_OF_TURN:
			_finish_player_turn_start_setup()
		Status.Type.END_OF_TURN:
			discard_cards()


func _on_relics_activated(type: Relic.Type) -> void:
	if not is_instance_valid(player) or not is_instance_valid(player.status_handler):
		push_error("PlayerHandler: player 或 status_handler 无效。")
		return
	match type:
		Relic.Type.START_OF_TURN:
			player.status_handler.apply_statuses_by_type(Status.Type.START_OF_TURN)
		Relic.Type.END_OF_TURN:
			player.status_handler.apply_statuses_by_type(Status.Type.END_OF_TURN)
