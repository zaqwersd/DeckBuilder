extends Card

## 心流 - 0费稀有技能
## 效果：抽2（3）张牌。消耗1张牌。[获得1点能量（待激活）]

const _MANA_GAIN_AMOUNT := 1


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["draw_count", "mana_gain"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	match track_id:
		"draw_count":
			## 2 = 未升级(抽2张)，3 = 已升级(抽3张)
			return PackedInt32Array([2, 3])
		"mana_gain":
			## 0 = 未升级(灰色)，1 = 已升级(激活)
			return PackedInt32Array([0, 0])
		_:
			return PackedInt32Array()


func _get_draw_count() -> int:
	return get_upgrade_value_at("draw_count")


func _can_gain_mana() -> bool:
	return is_upgrade_track_maxed("mana_gain")


## 营火/牌库：可点击的黄色数字；满级为白字
func _draw_count_bbcode_pick() -> String:
	return bbcode_upgrade_pick_digit("draw_count", _get_draw_count())


## 战斗：白色数字
func _draw_count_bbcode_combat() -> String:
	return "[color=%s]%d[/color]" % [COMBAT_BODY_TEXT, _get_draw_count()]


## 营火/牌库：灰色可点击词条；已激活为白字
func _mana_line_bbcode_pick() -> String:
	if _can_gain_mana():
		return "获得1点能量。"
	return CardKeywordTokens.bb_inactive_keyword("获得1点能量。", "mana_gain")


## 战斗：未激活不显示，已激活白字
func _mana_line_bbcode_combat() -> String:
	if not _can_gain_mana():
		return ""
	return "[color=%s]获得1点能量。[/color]" % COMBAT_BODY_TEXT


## 营火升级选择描述
func get_upgrade_pick_description_bbcode() -> String:
	return "[center]抽%s张牌。[br]消耗1张手牌。[br]%s[/center]" % [
		_draw_count_bbcode_pick(),
		_mana_line_bbcode_pick()
	]


## 默认提示文本（营火/牌库列表）
func get_default_tooltip() -> String:
	return get_upgrade_pick_description_bbcode()


## 更新的提示文本
func get_updated_tooltip(
	_player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler, _combat_player: Node = null
) -> String:
	return get_default_tooltip()


## 卡面描述
func get_visual_description_bbcode() -> String:
	return get_updated_visual_description_bbcode(null, null, null)


## 战斗场景更新的卡面描述
func get_updated_visual_description_bbcode(
	_player_modifiers: ModifierHandler,
	_enemy_modifiers: ModifierHandler,
	_combat_player: Node = null
) -> String:
	if is_visual_number_bbcode_combat():
		var mana_line := _mana_line_bbcode_combat()
		if mana_line.is_empty():
			return "[center]抽%s张牌。[br]消耗1张手牌。[/center]" % _draw_count_bbcode_combat()
		return "[center]抽%s张牌。[br]消耗1张手牌。[br]%s[/center]" % [
			_draw_count_bbcode_combat(),
			mana_line
		]
	return get_upgrade_pick_description_bbcode()


func plays_card_sound_on_play() -> bool:
	return true


func apply_effects(_targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return

	var ph := tree.get_first_node_in_group("player_handler") as PlayerHandler
	if ph == null:
		return

	var hand := ph.hand
	if hand == null:
		return

	## 1. 抽牌
	var draw_count := _get_draw_count()
	ph.draw_cards(draw_count)

	## 2. 等待抽牌动画完成
	await tree.create_timer(0.4).timeout
	await tree.process_frame

	## 3. 重新获取手牌引用
	hand = ph.hand
	if hand == null:
		return

	## 4. 检查是否有可选手牌
	var has_any := false
	for slot in hand.get_children():
		var cui := hand.get_card_ui_in_slot(slot)
		if cui != null and cui.card != null and cui.modulate.a > 0.01:
			has_any = true
			break
	if not has_any:
		return

	## 5. 打开手牌选择界面（强制选择，不可ESC取消）
	var overlay := HandCardPickOverlay.open_on_tree(
		tree, hand, 1, Callable(), "选择要消耗的卡牌", false
	)
	var result: Array = await overlay.selection_finished

	if not result[0]:
		## 玩家取消
		return

	var selected_cards: Array = result[1]
	if selected_cards.is_empty():
		return

	## 6. 消耗选中的卡牌（参考超脱卡牌的方式）
	var ch := ph.character
	var bcf := ph.battle_card_fx

	for card in selected_cards:
		if card == null:
			continue
		for slot in hand.get_children():
			var cui := hand.get_card_ui_in_slot(slot)
			if cui == null or cui.card != card:
				continue
			ch.add_card_to_exhaust(cui.card)
			if is_instance_valid(bcf) and bcf is BattleCardFx:
				var start_c := cui.get_global_rect().get_center()
				cui.modulate.a = 0.0
				if is_instance_valid(cui.hand_slot):
					hand.collapse_slot_for_exhaust_animation(cui.hand_slot)
				await (bcf as BattleCardFx).animate_played_card(
					cui.card, start_c, BattleCardFx.PlayedKind.EXHAUST
				)
				if is_instance_valid(hand) and is_instance_valid(cui) and not cui.is_queued_for_deletion():
					hand.discard_card(cui)
					hand.resync_layout_after_draw()
			else:
				hand.discard_card(cui)
				hand.resync_layout_after_draw()
			break

	## 7. 如果升级了mana_gain，获得能量
	if _can_gain_mana():
		ph.character.mana += _MANA_GAIN_AMOUNT
