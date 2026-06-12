extends Card

const DRAFTABLE_POOL_PATH := "res://characters/blade/blade_draftable_cards.tres"
const _PICK_UPGRADE_TEXT := "将其升级"
const _EXHAUST_LINE := "消耗。"


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["pick_upgrade"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	if track_id == "pick_upgrade":
		return PackedInt32Array([0, 0])
	return PackedInt32Array()


func _pick_upgrade_active() -> bool:
	return is_upgrade_track_maxed("pick_upgrade")


func _effect_body_bbcode() -> String:
	if _pick_upgrade_active():
		return "从本角色全卡池中选择一张牌，%s并加入你的抽牌堆底部。" % _PICK_UPGRADE_TEXT
	return "从本角色全卡池中选择一张牌，并加入你的抽牌堆底部。"


func _exhaust_line_bbcode() -> String:
	if not exhausts:
		return ""
	return _EXHAUST_LINE


func _append_exhaust_line_bbcode(body: String) -> String:
	var line := _exhaust_line_bbcode()
	if line.is_empty():
		return body
	return "%s%s" % [body, line]


func _description_bbcode() -> String:
	return "[center]%s[/center]" % _append_exhaust_line_bbcode(_effect_body_bbcode())


func get_upgrade_pick_description_bbcode() -> String:
	return _description_bbcode()


func get_default_tooltip() -> String:
	return _description_bbcode()


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
	return _description_bbcode()


func defers_played_card_animation_to_effects() -> bool:
	return true


func defers_exhaust_to_end_of_play() -> bool:
	return true


func plays_card_sound_on_play() -> bool:
	return true


func _dismiss_overlay(overlay: Node) -> void:
	if is_instance_valid(overlay) and overlay.is_inside_tree():
		overlay.queue_free()


func apply_effects(_targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var ph := tree.get_first_node_in_group("player_handler") as PlayerHandler
	if ph == null or ph.character == null:
		return

	var pool := load(DRAFTABLE_POOL_PATH) as CardPile
	if pool == null:
		return

	var temp_pile := CardPile.new()
	for c: Card in pool.cards:
		if c == null:
			continue
		temp_pile.add_card(c.duplicate(true) as Card)
	if temp_pile.cards.is_empty():
		return

	var want_pick_upgrade := _pick_upgrade_active()

	var overlay := DeckPickerOverlay.open_on_tree(tree)
	overlay.setup(
		temp_pile,
		1,
		Callable(),
		"选择一张卡牌加入抽牌堆底部。",
		PackedStringArray(),
		Callable(),
		Callable(),
		false,
		want_pick_upgrade
	)
	var indices: Array = await overlay.pick_confirmed
	_dismiss_overlay(overlay)

	if indices.is_empty():
		return

	var idx := int(indices[0])
	if idx < 0 or idx >= temp_pile.cards.size():
		return

	var chosen_ref: Card = temp_pile.cards[idx]

	if want_pick_upgrade and chosen_ref.can_be_upgraded():
		var flow := CardUpgradeFlow.open_on_tree(tree)
		flow.begin(temp_pile, idx)
		var result: int = await flow.finished
		if result != CardUpgradeFlow.Result.UPGRADED:
			return

	var chosen := temp_pile.cards[idx].duplicate(true) as Card
	if chosen == null:
		return

	var bcf := ph.battle_card_fx
	var fallback_center := Vector2.ZERO
	if is_instance_valid(bcf):
		fallback_center = bcf.get_viewport().get_visible_rect().get_center()
	var start_center := consume_play_visual_start_center(fallback_center)

	var insert_at_bottom := ph.character.draw_pile.cards.size()
	if is_instance_valid(bcf) and bcf is BattleCardFx and not Events.is_combat_ended():
		var fx := bcf as BattleCardFx
		await fx.animate_insert_into_draw_pile(chosen, Vector2.ZERO, ph.character, insert_at_bottom)
		if Events.is_combat_ended():
			return
		await fx.animate_played_card(self, start_center, BattleCardFx.PlayedKind.EXHAUST)
	else:
		ph.character.draw_pile.insert_card_at(insert_at_bottom, chosen)
