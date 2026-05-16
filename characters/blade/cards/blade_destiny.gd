extends Card

const DRAFTABLE_POOL_PATH := "res://characters/blade/blade_draftable_cards.tres"


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["cost", "intrinsic_line", "pick_upgrade"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	match track_id:
		"cost":
			return PackedInt32Array([1, 0])
		"intrinsic_line":
			return PackedInt32Array([0, 0])
		"pick_upgrade":
			return PackedInt32Array([0, 0])
		_:
			return PackedInt32Array()


func _intrinsic_line_bb_pick() -> String:
	if is_upgrade_track_maxed("intrinsic_line"):
		return "[color=#ffffff]固有。[/color]"
	return "[url=ugp:intrinsic_line][color=%s]固有。[/color][/url]" % BB_UPGRADE_INACTIVE_KEYWORD


const _PICK_UPGRADE_TEXT := "将其升级"
const _EXHAUST_LINE := "消耗。"


func _exhaust_line_bbcode() -> String:
	return _EXHAUST_LINE


func _append_exhaust_line_bbcode(body: String) -> String:
	if not exhausts:
		return body
	return "%s%s" % [body, _exhaust_line_bbcode()]


## 营火/列表：未激活时灰色可点轨；已激活为普通字。
func _pick_upgrade_clause_listing_bbcode() -> String:
	if is_upgrade_track_maxed("pick_upgrade"):
		return _PICK_UPGRADE_TEXT
	return CardKeywordTokens.bb_inactive_keyword(_PICK_UPGRADE_TEXT, "pick_upgrade")


## 战斗：未激活时不显示该段；已激活为白字「将其升级」。
func _pick_upgrade_clause_combat_bbcode() -> String:
	if not is_upgrade_track_maxed("pick_upgrade"):
		return ""
	if is_visual_number_bbcode_combat():
		return "[color=%s]%s[/color]" % [COMBAT_BODY_TEXT, _PICK_UPGRADE_TEXT]
	return _PICK_UPGRADE_TEXT


func _effect_line_bbcode_for_listing() -> String:
	return "从本角色全卡池中选择一张牌，%s并加入你的抽牌堆底部。" % _pick_upgrade_clause_listing_bbcode()


func _effect_line_bbcode_for_combat() -> String:
	var clause := _pick_upgrade_clause_combat_bbcode()
	if clause.is_empty():
		return "从本角色全卡池中选择一张牌，并加入你的抽牌堆底部。"
	return "从本角色全卡池中选择一张牌，%s并加入你的抽牌堆底部。" % clause


func get_upgrade_pick_description_bbcode() -> String:
	var body := _append_exhaust_line_bbcode(_effect_line_bbcode_for_listing())
	return "[center]%s[br]%s[/center]" % [_intrinsic_line_bb_pick(), body]


func get_default_tooltip() -> String:
	var effect: String
	if is_upgrade_track_maxed("pick_upgrade"):
		effect = "从本角色全卡池中选择一张牌，将其升级并加入你的抽牌堆底部。"
	else:
		var gray := CardKeywordTokens.bb_inactive_keyword(_PICK_UPGRADE_TEXT, "pick_upgrade")
		effect = "从本角色全卡池中选择一张牌，%s并加入你的抽牌堆底部。" % gray
	return "[center]%s[/center]" % _append_exhaust_line_bbcode(effect)


func get_updated_tooltip(
	_player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler, _combat_player: Node = null
) -> String:
	return get_default_tooltip()


func get_visual_description_bbcode() -> String:
	return get_updated_visual_description_bbcode(null, null, null)


func get_updated_visual_description_bbcode(
	_player_modifiers: ModifierHandler,
	_enemy_modifiers: ModifierHandler,
	combat_player: Node = null
) -> String:
	## 列表/图鉴（LISTING_UPGRADE）：灰字可升轨「将其升级」；战斗（COMBAT）：未激活不显示该段。
	var body := (
		_effect_line_bbcode_for_combat()
		if is_visual_number_bbcode_combat()
		else _effect_line_bbcode_for_listing()
	)
	body = _append_exhaust_line_bbcode(body)
	return "[center]%s[/center]" % body


func _intrinsic_cost() -> int:
	return get_upgrade_value_at("cost")


func should_visualize_cost_as_upgradeable() -> bool:
	var ch := get_upgrade_chain("cost")
	if ch.is_empty():
		return false
	return not is_upgrade_track_maxed("cost")


func increment_upgrade_track(track_id: String) -> void:
	super.increment_upgrade_track(track_id)
	if track_id == "cost":
		cost = _intrinsic_cost()


func sync_unlocked_intrinsic_flags_from_upgrade_tracks() -> void:
	var ch := get_upgrade_chain("intrinsic_line")
	if ch.is_empty():
		return
	intrinsic = is_upgrade_track_maxed("intrinsic_line")


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

	var want_pick_upgrade := is_upgrade_track_maxed("pick_upgrade")

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

	if want_pick_upgrade and chosen_ref.has_any_upgradeable_track():
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
