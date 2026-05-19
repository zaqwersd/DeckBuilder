extends Card

var exhaust_amount := 1

## 选牌 UI：`selection_finished` 回调写入，`finished` 为 true 后 `_show_card_selector` 继续
var _selector_close_state: Dictionary = {}


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["block", "discard_mode"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	match track_id:
		"block":
			return PackedInt32Array([8, 11, 15])
		"discard_mode":
			return PackedInt32Array([0, 0])
		_:
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


func get_upgrade_pick_description_bbcode() -> String:
	var rnd := ""
	if not is_upgrade_track_maxed("discard_mode"):
		rnd = CardKeywordTokens.bb_negative_removable("随机", "discard_mode")
	return "[center]%s。[br]%s消耗1张手牌。[/center]" % [_block_line_upgrade_pick_bbcode(), rnd]


func get_default_tooltip() -> String:
	if is_upgrade_track_maxed("discard_mode"):
		return "[center]%s。[br]消耗1张手牌。[/center]" % _block_line_listing_bbcode()
	var rnd := "[color=%s]随机[/color]" % CardUpgradeUiColors.BB_NEGATIVE_REMOVABLE
	return "[center]%s。[br]%s消耗1张手牌。[/center]" % [_block_line_listing_bbcode(), rnd]


func get_updated_tooltip(
	_player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler, _combat_player: Node = null
) -> String:
	return get_default_tooltip()


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var block_value := get_upgrade_value_at("block")
	var block_effect := BlockEffect.new()
	block_effect.amount = block_value
	block_effect.sound = sound
	block_effect.execute(targets)

	if is_upgrade_track_maxed("discard_mode"):
		await _show_card_selector()
	else:
		var exhaust_random_effect := ExhaustRandomEffect.new()
		exhaust_random_effect.amount = exhaust_amount
		await exhaust_random_effect.execute(targets)


func _show_card_selector() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var hand := _get_hand()
	if hand == null or hand.get_child_count() == 0:
		return

	var has_any := false
	for slot in hand.get_children():
		var cui := hand.get_card_ui_in_slot(slot)
		if cui != null and cui.card != null and cui.modulate.a > 0.01:
			has_any = true
			break
	if not has_any:
		return

	## allow_cancel = false：强制选择，不可ESC取消
	var overlay := HandCardPickOverlay.open_on_tree(
		tree, hand, 1, Callable(), "选择要消耗的卡牌", false
	)
	_selector_close_state = {"finished": false}
	overlay.selection_finished.connect(_on_selector_screen_finished, CONNECT_ONE_SHOT)

	while not bool(_selector_close_state.get("finished", false)):
		await tree.process_frame

	if bool(_selector_close_state.get("confirmed", false)):
		var picked: Variant = _selector_close_state.get("cards", [])
		if picked is Array and not (picked as Array).is_empty():
			await _exhaust_selected_cards(hand, picked as Array)


func _on_selector_screen_finished(confirmed: bool, selected_cards: Array) -> void:
	_selector_close_state = {
		"finished": true,
		"confirmed": confirmed,
		"cards": selected_cards,
	}


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
