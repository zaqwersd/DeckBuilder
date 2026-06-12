extends Card

const DRAFTABLE_POOL_PATH := "res://characters/blade/blade_draftable_cards.tres"

const _EFFECT_BODY := "变化你消耗堆的所有牌，将它们升级并放入你的抽牌堆。"
const _EXHAUST_LINE := "消耗。"


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["exhaust_line"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	if track_id == "exhaust_line":
		return PackedInt32Array([0, 0])
	return PackedInt32Array()


func _exhaust_line_bbcode() -> String:
	if not exhausts:
		return ""
	return _EXHAUST_LINE


func _append_exhaust_line_bbcode(body: String) -> String:
	var line := _exhaust_line_bbcode()
	if line.is_empty():
		return body
	return "%s%s" % [body, line]


func _effect_body_bbcode() -> String:
	return _EFFECT_BODY


func get_upgrade_pick_description_bbcode() -> String:
	return "[center]%s[/center]" % _append_exhaust_line_bbcode(_effect_body_bbcode())


func get_default_tooltip() -> String:
	return "[center]%s[/center]" % _append_exhaust_line_bbcode(_effect_body_bbcode())


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
	return "[center]%s[/center]" % _append_exhaust_line_bbcode(_effect_body_bbcode())


func _apply_upgraded_state() -> void:
	super._apply_upgraded_state()
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


func _maybe_upgrade_transformed_card(card: Card) -> void:
	if card != null and card.can_be_upgraded():
		card.apply_upgrade()


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
		_maybe_upgrade_transformed_card(new_card)
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
