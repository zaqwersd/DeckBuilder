extends Card

const DRAFTABLE_POOL_PATH := "res://characters/blade/blade_draftable_cards.tres"

const _RANDOM_UPGRADE_CLAUSE := "随机升级以后"
const _EXHAUST_LINE := "消耗。"


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["cost", "exhaust_line", "random_upgrade_line"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	match track_id:
		"cost":
			return PackedInt32Array([1, 0])
		"exhaust_line":
			return PackedInt32Array([0, 0])
		"random_upgrade_line":
			return PackedInt32Array([0, 0])
		_:
			return PackedInt32Array()


func uses_random_upgrade_track_pick() -> bool:
	return true


func _intrinsic_cost() -> int:
	return get_upgrade_value_at("cost")


func _exhaust_line_bbcode() -> String:
	if not exhausts:
		return ""
	if is_upgrade_track_maxed("exhaust_line"):
		return ""
	return CardKeywordTokens.bb_negative_removable(_EXHAUST_LINE, "exhaust_line")


func _append_exhaust_line_bbcode(body: String) -> String:
	var line := _exhaust_line_bbcode()
	if line.is_empty():
		return body
	return "%s%s" % [body, line]


func _random_upgrade_clause_listing_bbcode() -> String:
	if is_upgrade_track_maxed("random_upgrade_line"):
		return _RANDOM_UPGRADE_CLAUSE
	return CardKeywordTokens.bb_inactive_keyword(_RANDOM_UPGRADE_CLAUSE, "random_upgrade_line")


func _random_upgrade_clause_combat_bbcode() -> String:
	if not is_upgrade_track_maxed("random_upgrade_line"):
		return ""
	if is_visual_number_bbcode_combat():
		return "[color=%s]%s[/color]" % [COMBAT_BODY_TEXT, _RANDOM_UPGRADE_CLAUSE]
	return _RANDOM_UPGRADE_CLAUSE


func _effect_body_bbcode_for_listing() -> String:
	return "变化你消耗堆的所有牌，然后将它们%s放入你的抽牌堆。" % _random_upgrade_clause_listing_bbcode()


func _effect_body_bbcode_for_combat() -> String:
	var clause := _random_upgrade_clause_combat_bbcode()
	if clause.is_empty():
		return "变化你消耗堆的所有牌，然后将它们放入你的抽牌堆。"
	return "变化你消耗堆的所有牌，然后将它们%s放入你的抽牌堆。" % clause


func get_upgrade_pick_description_bbcode() -> String:
	return "[center]%s[/center]" % _append_exhaust_line_bbcode(_effect_body_bbcode_for_listing())


func get_default_tooltip() -> String:
	var body: String
	if is_upgrade_track_maxed("random_upgrade_line"):
		body = "变化你消耗堆的所有牌，然后将它们随机升级以后放入你的抽牌堆。"
	else:
		var gray := CardKeywordTokens.bb_inactive_keyword(_RANDOM_UPGRADE_CLAUSE, "random_upgrade_line")
		body = "变化你消耗堆的所有牌，然后将它们%s放入你的抽牌堆。" % gray
	return "[center]%s[/center]" % _append_exhaust_line_bbcode(body)


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
	var body := (
		_effect_body_bbcode_for_combat()
		if is_visual_number_bbcode_combat()
		else _effect_body_bbcode_for_listing()
	)
	return "[center]%s[/center]" % _append_exhaust_line_bbcode(body)


func should_visualize_cost_as_upgradeable() -> bool:
	var ch := get_upgrade_chain("cost")
	if ch.is_empty():
		return false
	return not is_upgrade_track_maxed("cost")


func increment_upgrade_track(track_id: String) -> void:
	super.increment_upgrade_track(track_id)
	if track_id == "cost":
		cost = _intrinsic_cost()
	_sync_exhaust_from_upgrade()


func sync_unlocked_intrinsic_flags_from_upgrade_tracks() -> void:
	_sync_exhaust_from_upgrade()


func _sync_exhaust_from_upgrade() -> void:
	var ch := get_upgrade_chain("exhaust_line")
	if ch.is_empty():
		return
	exhausts = not is_upgrade_track_maxed("exhaust_line")


func defers_played_card_animation_to_effects() -> bool:
	return true


func defers_exhaust_to_end_of_play() -> bool:
	return exhausts


func plays_card_sound_on_play() -> bool:
	return true


func _roll_draftable_card() -> Card:
	var pool := load(DRAFTABLE_POOL_PATH) as CardPile
	if pool == null or pool.cards.is_empty():
		return null
	var template: Card = RNG.array_pick_random(pool.cards) as Card
	if template == null:
		return null
	return template.duplicate(true) as Card


func _maybe_random_upgrade_transformed_card(card: Card) -> void:
	if not is_upgrade_track_maxed("random_upgrade_line"):
		return
	if card == null or not card.has_any_upgradeable_track():
		return
	var track_id := card.pick_random_upgrade_track()
	if track_id.is_empty():
		return
	card.increment_upgrade_track(track_id)


func apply_effects(_targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var ph := tree.get_first_node_in_group("player_handler") as PlayerHandler
	if ph == null or ph.character == null:
		return

	var char_stats := ph.character
	var old_cards: Array[Card] = []
	for c: Card in char_stats.exhaust.cards:
		if c != null:
			old_cards.append(c)
	char_stats.exhaust.clear()

	var pairs: Array[Dictionary] = []
	for old_card: Card in old_cards:
		var new_card := _roll_draftable_card()
		if new_card == null:
			continue
		_maybe_random_upgrade_transformed_card(new_card)
		pairs.append({"old": old_card, "new": new_card})

	var bcf := ph.battle_card_fx
	var fallback_center := Vector2.ZERO
	if is_instance_valid(bcf):
		fallback_center = bcf.get_viewport().get_visible_rect().get_center()
	var start_center := consume_play_visual_start_center(fallback_center)

	if is_instance_valid(bcf) and bcf is BattleCardFx and not Events.is_combat_ended():
		var fx := bcf as BattleCardFx
		await fx.animate_samsara_transform(self, pairs, start_center, char_stats)
		if Events.is_combat_ended():
			return
		var end_center := start_center
		if is_instance_valid(bcf):
			end_center = bcf.get_viewport().get_visible_rect().get_center()
		await fx.animate_samsara_resolve(self, end_center, exhausts)
	else:
		for pair: Dictionary in pairs:
			var nc: Card = pair.get("new")
			if nc != null:
				char_stats.draw_pile.add_card(nc)
