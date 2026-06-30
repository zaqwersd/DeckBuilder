extends Card


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["block", "draw"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	match track_id:
		"block":
			return PackedInt32Array([8, 12])
		"draw":
			return PackedInt32Array([1, 1])
		_:
			return PackedInt32Array()


func get_upgrade_pick_description_bbcode() -> String:
	var b := get_upgrade_value_at("block")
	var dr := get_upgrade_value_at("draw")
	return "[center]获得%s点格挡。[br]抽%s张牌。[/center]" % [
		bbcode_upgrade_pick_digit("block", b),
		bbcode_upgrade_pick_digit("draw", dr),
	]


func _intrinsic_block() -> int:
	return get_upgrade_value_at("block")


func _intrinsic_draw() -> int:
	return get_upgrade_value_at("draw")


func get_default_tooltip() -> String:
	return tooltip_text % [_intrinsic_block(), _intrinsic_draw()]


func get_updated_tooltip(
	_player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler, _combat_player: Node = null
) -> String:
	var intrinsic_b := _intrinsic_block()
	var b := effective_block_from_card_play(intrinsic_b, _combat_player)
	var d := _intrinsic_draw()
	var block_bb := bbcode_for_modified_number_with_upgrade_hint(
		b, intrinsic_b, is_upgrade_track_maxed("block")
	)
	var draw_bb := bbcode_for_modified_number_with_upgrade_hint(
		d, d, is_upgrade_track_maxed("draw")
	)
	return tooltip_text % [block_bb, draw_bb]


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var block_effect := BlockEffect.new()
	block_effect.amount = _intrinsic_block()
	block_effect.from_card_play = true
	block_effect.execute(targets)

	var card_draw_effect := CardDrawEffect.new()
	card_draw_effect.cards_to_draw = _intrinsic_draw()
	await card_draw_effect.execute(targets)
