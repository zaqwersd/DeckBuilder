extends Card

## 取舍 - 1费技能：获得格挡，选择消耗1张手牌。


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["block"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	if track_id == "block":
		return PackedInt32Array([8, 12])
	return PackedInt32Array()


func _block_chain_first() -> int:
	var ch := get_upgrade_chain("block")
	if ch.is_empty():
		return get_upgrade_value_at("block")
	return int(ch[0])


## 卡面/提示：只显示当前格挡；格挡轨满级为白字，未满级按与链首比较着色。
func _block_current_colored_bbcode() -> String:
	var cur := get_upgrade_value_at("block")
	var first := _block_chain_first()
	var mx := is_upgrade_track_maxed("block")
	var combat := Card.is_visual_number_bbcode_combat()

	if mx:
		if combat:
			return "[color=%s]%d[/color]" % [Card.COMBAT_BODY_TEXT, cur]
		return str(cur)

	if cur < first:
		if combat:
			return "[color=%s]%d[/color]" % [Card.COMBAT_MODIFIED_RED, cur]
		return "[color=%s]%d[/color]" % [CardUpgradeUiColors.BB_NEGATIVE_REMOVABLE, cur]
	if cur > first:
		return "[color=%s]%d[/color]" % [Card.BB_COLOR_UPGRADEABLE, cur]
	if combat:
		return "[color=%s]%d[/color]" % [Card.COMBAT_BODY_TEXT, cur]
	return "[color=%s]%d[/color]" % [Card.BB_COLOR_UPGRADEABLE, cur]


func _block_line_listing_bbcode() -> String:
	return "获得%s点格挡" % _block_current_colored_bbcode()


func _block_line_upgrade_pick_bbcode() -> String:
	if is_upgrade_track_maxed("block"):
		var v := get_upgrade_value_at("block")
		return "获得[color=%s]%d[/color]点格挡" % [Card.COMBAT_BODY_TEXT, v]
	return "获得%s点格挡" % bbcode_upgrade_pick_digit("block", get_upgrade_value_at("block"))


func _exhaust_line_bbcode() -> String:
	return "消耗1张手牌"


func get_upgrade_pick_description_bbcode() -> String:
	return "[center]%s。[br]%s。[/center]" % [_block_line_upgrade_pick_bbcode(), _exhaust_line_bbcode()]


func get_default_tooltip() -> String:
	return "[center]%s。[br]%s。[/center]" % [_block_line_listing_bbcode(), _exhaust_line_bbcode()]


func get_updated_tooltip(
	_player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler, _combat_player: Node = null
) -> String:
	var intrinsic_b := get_upgrade_value_at("block")
	var block_bb := bbcode_for_modified_number_with_upgrade_hint(
		effective_block_from_card_play(intrinsic_b, _combat_player),
		intrinsic_b,
		is_upgrade_track_maxed("block")
	)
	return "[center]获得%s点格挡。[br]%s。[/center]" % [block_bb, _exhaust_line_bbcode()]


func meets_play_requirements(_char_stats: CharacterStats) -> bool:
	return true


func _count_pickable_hand_cards() -> int:
	var hand := _get_hand()
	if hand == null:
		return 0
	var n := 0
	for slot in hand.get_children():
		var cui := hand.get_card_ui_in_slot(slot)
		if cui == null or cui.card == null or cui.modulate.a <= 0.01:
			continue
		n += 1
	return n


func allows_hand_drag_when_play_requirements_unmet() -> bool:
	return true


func requires_drag_outside_hand_before_play() -> bool:
	return true


func opens_hand_card_pick_on_play() -> bool:
	return true


var _pending_pick_overlay: HandCardPickOverlay = null


func prepare_hand_card_pick_before_effects() -> void:
	if _count_pickable_hand_cards() <= 0:
		return
	_pending_pick_overlay = _open_pick_overlay_sync()


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var block_effect := BlockEffect.new()
	block_effect.amount = get_upgrade_value_at("block")
	block_effect.from_card_play = true
	block_effect.execute(targets)
	await _await_card_selector()


func _open_pick_overlay_sync() -> HandCardPickOverlay:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var hand := _get_hand()
	if hand == null or _count_pickable_hand_cards() <= 0:
		return null
	## allow_cancel = false：强制选择，不可ESC取消
	return HandCardPickOverlay.open_on_tree(
		tree, hand, 1, Callable(), "选择要消耗的卡牌", false
	)


func _await_card_selector() -> void:
	if _pending_pick_overlay == null or not is_instance_valid(_pending_pick_overlay):
		prepare_hand_card_pick_before_effects()
	var overlay := _pending_pick_overlay
	_pending_pick_overlay = null
	if overlay == null or not is_instance_valid(overlay):
		return
	var hand := _get_hand()
	if hand == null:
		return
	var result: Array = await overlay.selection_finished
	if not result[0]:
		return
	var selected_cards: Array = result[1]
	if selected_cards.is_empty():
		return
	await _exhaust_selected_cards(hand, selected_cards)


func _exhaust_selected_cards(hand: Hand, selected_cards: Array) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var ph := tree.get_first_node_in_group("player_handler") as PlayerHandler
	if ph == null or ph.character == null:
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


func _get_hand() -> Hand:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var ph := tree.get_first_node_in_group("player_handler") as PlayerHandler
	if ph != null and is_instance_valid(ph.hand):
		return ph.hand
	var scene := tree.current_scene
	if scene != null:
		var h := scene.get_node_or_null("BattleUI/Hand")
		if h is Hand:
			return h as Hand
	return null
