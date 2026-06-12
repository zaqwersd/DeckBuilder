extends Card

const NEXT_TURN_MANA_STATUS := preload("res://statuses/next_turn_mana.tres")


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["block"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	match track_id:
		"block":
			return PackedInt32Array([10, 15])
		_:
			return PackedInt32Array()


func _intrinsic_block() -> int:
	return get_upgrade_value_at("block")


func get_upgrade_pick_description_bbcode() -> String:
	var b := get_upgrade_value_at("block")
	return "[center]获得%s点格挡。[br]下回合获得当前能量值的能量。[/center]" % [
		bbcode_upgrade_pick_digit("block", b),
	]


func get_default_tooltip() -> String:
	return tooltip_text % [_intrinsic_block()]


func get_updated_tooltip(
	_player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler, _combat_player: Node = null
) -> String:
	var intrinsic_b := _intrinsic_block()
	var block_bb := bbcode_for_modified_number_with_upgrade_hint(
		effective_block_from_card_play(intrinsic_b, _combat_player),
		intrinsic_b,
		is_upgrade_track_maxed("block")
	)
	return tooltip_text % [block_bb]


func plays_card_sound_on_play() -> bool:
	return true


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var block_effect := BlockEffect.new()
	block_effect.amount = _intrinsic_block()
	block_effect.from_card_play = true
	block_effect.sound = sound
	block_effect.execute(targets)

	if targets.is_empty():
		return

	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var ph := tree.get_first_node_in_group("player_handler") as PlayerHandler
	if ph == null or ph.character == null:
		return
	var remaining := ph.character.mana
	if remaining <= 0:
		return

	var status_handler: StatusHandler = targets[0].get("status_handler")
	if status_handler == null:
		return
	var next_turn_mana := NEXT_TURN_MANA_STATUS.duplicate(true) as NextTurnManaStatus
	if next_turn_mana == null:
		return
	next_turn_mana.mana_to_grant = remaining
	status_handler.add_status(next_turn_mana)
