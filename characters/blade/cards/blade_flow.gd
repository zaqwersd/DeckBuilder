extends Card

## 心流 - 1费 uncommon 技能：抽2（3）张牌，消耗1张手牌。


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["draw_count"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	if track_id == "draw_count":
		return PackedInt32Array([2, 3])
	return PackedInt32Array()


func _get_draw_count() -> int:
	return get_upgrade_value_at("draw_count")


func _draw_count_bbcode() -> String:
	return bbcode_upgrade_pick_digit("draw_count", _get_draw_count())


func get_upgrade_pick_description_bbcode() -> String:
	return "[center]抽%s张牌。[br]消耗1张手牌。[/center]" % _draw_count_bbcode()


func get_default_tooltip() -> String:
	return get_upgrade_pick_description_bbcode()


func get_updated_tooltip(
	_player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler, _combat_player: Node = null
) -> String:
	return get_default_tooltip()


func get_visual_description_bbcode() -> String:
	return get_updated_visual_description_bbcode(null, null, null)


func get_updated_visual_description_bbcode(
	_player_modifiers: ModifierHandler,
	_enemy_modifiers: ModifierHandler,
	_combat_player: Node = null
) -> String:
	if is_visual_number_bbcode_combat():
		return "[center]抽%s张牌。[br]消耗1张手牌。[/center]" % (
			"[color=%s]%d[/color]" % [COMBAT_BODY_TEXT, _get_draw_count()]
		)
	return get_upgrade_pick_description_bbcode()


func plays_card_sound_on_play() -> bool:
	return true


func requires_drag_outside_hand_before_play() -> bool:
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

	var draw_count := _get_draw_count()
	await ph.draw_cards(draw_count, false, false, true)
	await tree.process_frame

	hand = ph.hand
	if hand == null:
		return

	var has_any := false
	for slot in hand.get_children():
		var cui := hand.get_card_ui_in_slot(slot)
		if cui != null and cui.card != null and cui.modulate.a > 0.01:
			has_any = true
			break
	if not has_any:
		return

	var overlay := HandCardPickOverlay.open_on_tree(
		tree, hand, 1, Callable(), "选择要消耗的卡牌", false
	)
	var result: Array = await overlay.selection_finished

	if not result[0]:
		return

	var selected_cards: Array = result[1]
	if selected_cards.is_empty():
		return

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
