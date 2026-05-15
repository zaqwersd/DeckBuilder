extends EventRoom

const DECK_OVERLAY := preload("res://scenes/ui/deck_picker_overlay.tscn")
const CARD_REWARDS := preload("res://scenes/ui/card_rewards.tscn")
const CARD_MENU_UI := preload("res://scenes/ui/card_menu_ui.tscn")
const IRON_WAVE := preload("res://common_cards/iron_wave.tres")
const IRON_PREVIEW_SCALE := 0.8
const IRON_PREVIEW_GAP := 16.0

@onready var option_strike_block: Button = %OptionStrikeBlock
@onready var option_two_pick: Button = %OptionTwoPick

var _iron_preview_menu: CardMenuUI


func _ready() -> void:
	call_deferred("_deferred_setup_iron_floating_preview")


func _deferred_setup_iron_floating_preview() -> void:
	if not is_instance_valid(option_strike_block):
		return
	_iron_preview_menu = CARD_MENU_UI.instantiate() as CardMenuUI
	add_child(_iron_preview_menu)
	_iron_preview_menu.top_level = true
	_iron_preview_menu.z_as_relative = false
	_iron_preview_menu.z_index = 80
	_iron_preview_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_iron_preview_menu.visuals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_iron_preview_menu.card = IRON_WAVE.duplicate(true) as Card
	_iron_preview_menu.scale = Vector2.ONE * IRON_PREVIEW_SCALE
	_iron_preview_menu.pivot_offset = Vector2(134.0, 174.0)
	_iron_preview_menu.hide()
	option_strike_block.mouse_entered.connect(_on_iron_preview_hover_in)
	option_strike_block.mouse_exited.connect(_on_iron_preview_hover_out)
	if option_strike_block.disabled:
		_iron_preview_menu.hide()


func _update_iron_preview_position() -> void:
	if not is_instance_valid(_iron_preview_menu) or not is_instance_valid(option_strike_block):
		return
	var s := IRON_PREVIEW_SCALE
	var card_size := Vector2(268.0 * s, 348.0 * s)
	var g := option_strike_block.global_position
	var top_left := Vector2(g.x - IRON_PREVIEW_GAP - card_size.x, g.y + (option_strike_block.size.y - card_size.y) * 0.5)
	var vp := get_viewport().get_visible_rect()
	top_left.x = clampf(top_left.x, vp.position.x + 8.0, vp.end.x - card_size.x - 8.0)
	top_left.y = clampf(top_left.y, vp.position.y + 8.0, vp.end.y - card_size.y - 8.0)
	_iron_preview_menu.global_position = top_left


func _on_iron_preview_hover_in() -> void:
	if option_strike_block.disabled or not is_instance_valid(_iron_preview_menu):
		return
	_iron_preview_menu.move_to_front()
	_update_iron_preview_position()
	_iron_preview_menu.show()


func _on_iron_preview_hover_out() -> void:
	call_deferred("_iron_preview_hover_out_deferred")


func _iron_preview_hover_out_deferred() -> void:
	if not is_instance_valid(_iron_preview_menu):
		return
	var mp := get_global_mouse_position()
	if is_instance_valid(option_strike_block) and option_strike_block.get_global_rect().has_point(mp):
		return
	if _iron_preview_menu.visible and _iron_preview_menu.get_global_rect().has_point(mp):
		return
	_iron_preview_menu.hide()


func setup() -> void:
	option_strike_block.disabled = not _deck_has_strike_and_block()
	option_two_pick.disabled = not _can_roll_attack_and_skill()
	if option_strike_block.disabled and is_instance_valid(_iron_preview_menu):
		_iron_preview_menu.hide()
	if not option_strike_block.pressed.is_connected(_on_option_strike_block):
		option_strike_block.pressed.connect(_on_option_strike_block)
	if not option_two_pick.pressed.is_connected(_on_option_two_pick):
		option_two_pick.pressed.connect(_on_option_two_pick)
	var run := get_tree().get_first_node_in_group("run") as Run
	var scene_path := scene_file_path
	if run != null and run.matches_pending_event(scene_path, "option_two"):
		_restore_option_two_rewards(run.get_pending_card_templates())
		return


func _deck_has_strike_and_block() -> bool:
	if character_stats == null:
		return false
	return _count_id("blade_strike") >= 1 and _count_id("blade_block") >= 1


func _count_id(which: String) -> int:
	var n := 0
	for c: Card in character_stats.deck.cards:
		if c.id == which:
			n += 1
	return n


func _can_roll_attack_and_skill() -> bool:
	if character_stats == null:
		return false
	var pool := character_stats.draftable_cards.duplicate_cards()
	var attacks: Array[Card] = []
	var skills: Array[Card] = []
	for c: Card in pool:
		if c.type == Card.Type.ATTACK:
			attacks.append(c)
		elif c.type == Card.Type.SKILL:
			skills.append(c)
	return not attacks.is_empty() and not skills.is_empty()


func _pick_attack_and_skill_templates() -> Array[Card]:
	var pool := character_stats.draftable_cards.duplicate_cards()
	var attacks: Array[Card] = []
	var skills: Array[Card] = []
	for c: Card in pool:
		if c.type == Card.Type.ATTACK:
			attacks.append(c)
		elif c.type == Card.Type.SKILL:
			skills.append(c)
	if attacks.is_empty() or skills.is_empty():
		return []
	var a: Card = RNG.array_pick_random(attacks) as Card
	var b: Card = RNG.array_pick_random(skills) as Card
	return [a, b]


func _validate_strike_and_block(indices: Array) -> bool:
	if character_stats == null or indices.size() != 2:
		return false
	var i0: int = int(indices[0])
	var i1: int = int(indices[1])
	var id0: String = character_stats.deck.cards[i0].id
	var id1: String = character_stats.deck.cards[i1].id
	return (id0 == "blade_strike" and id1 == "blade_block") or (id0 == "blade_block" and id1 == "blade_strike")


func _on_option_strike_block() -> void:
	if option_strike_block.disabled or character_stats == null:
		return
	if is_instance_valid(_iron_preview_menu):
		_iron_preview_menu.hide()
	option_strike_block.disabled = true
	option_two_pick.disabled = true
	var overlay := DECK_OVERLAY.instantiate() as DeckPickerOverlay
	overlay.z_index = 200
	overlay.z_as_relative = false
	add_child(overlay)
	var allowed := PackedStringArray(["blade_strike", "blade_block"])
	overlay.setup(
		character_stats.deck,
		2,
		_validate_strike_and_block,
		"选择一张打击和一张防御。",
		allowed,
		Callable(self, "_validate_strike_and_block"),
		Callable()
	)
	var indices: Array = await overlay.pick_confirmed
	if indices.is_empty():
		option_strike_block.disabled = not _deck_has_strike_and_block()
		option_two_pick.disabled = not _can_roll_attack_and_skill()
		return
	indices.sort()
	# 先移除两张牌（从后往前移除以避免索引变化问题）
	var cards_to_remove: Array[Card] = []
	for j in range(indices.size() - 1, -1, -1):
		var deck_index: int = int(indices[j])
		var removed: Card = character_stats.deck.remove_card_at(deck_index)
		cards_to_remove.append(removed)
	
	# 同时播放两张牌的淡出动画
	var run := get_tree().get_first_node_in_group("run") as Run
	if run and cards_to_remove.size() >= 2:
		await run.play_deck_remove_two_cards_fade_and_wait(cards_to_remove[0], cards_to_remove[1])
	
	var gained: Card = IRON_WAVE.duplicate(true) as Card
	character_stats.deck.add_card(gained)
	if run:
		run.play_deck_gain_card_visual(gained, Vector2.ZERO)
	call_deferred("_finish_event_and_leave")


func _on_option_two_pick() -> void:
	if option_two_pick.disabled or character_stats == null:
		return
	var pair := _pick_attack_and_skill_templates()
	if pair.is_empty():
		return
	var run := get_tree().get_first_node_in_group("run") as Run
	if run != null:
		var ids := PackedStringArray([pair[0].id, pair[1].id])
		run.persist_event_card_reward_pending(scene_file_path, "option_two", ids)
	_show_option_two_rewards(pair)


func _restore_option_two_rewards(pair: Array[Card]) -> void:
	if pair.is_empty():
		return
	_show_option_two_rewards(pair)


func _show_option_two_rewards(pair: Array[Card]) -> void:
	option_two_pick.disabled = true
	option_strike_block.disabled = true
	var rewards := CARD_REWARDS.instantiate() as CardRewards
	add_child(rewards)
	rewards.rewards = pair
	rewards.card_reward_selected.connect(_on_option_two_reward_picked, CONNECT_ONE_SHOT)


func _on_option_two_reward_picked(menu: Variant, from_global: Vector2) -> void:
	var run := get_tree().get_first_node_in_group("run") as Run
	if run != null:
		run.clear_room_pending_and_save()
	_on_pair_reward_selected(menu, from_global)
	call_deferred("_finish_event_and_leave")


func _on_pair_reward_selected(picked_menu: Variant, from_global: Vector2) -> void:
	if character_stats == null:
		return
	if picked_menu != null and picked_menu is CardMenuUI:
		var menu := picked_menu as CardMenuUI
		if menu.card:
			var copy: Card = menu.card.duplicate(true) as Card
			character_stats.deck.add_card(copy)
			var run := get_tree().get_first_node_in_group("run") as Run
			if run:
				run.play_deck_gain_card_visual_with_pick(menu, from_global)


func _finish_event_and_leave() -> void:
	Events.event_room_exited.emit()
