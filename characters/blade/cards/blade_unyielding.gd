extends Card


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["hp_threshold", "block"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	match track_id:
		"hp_threshold":
			return PackedInt32Array([10, 17])
		"block":
			return PackedInt32Array([45, 45])
		_:
			return PackedInt32Array()


func meets_play_requirements(char_stats: CharacterStats) -> bool:
	return char_stats.health <= get_upgrade_value_at("hp_threshold")


func allows_hand_drag_when_play_requirements_unmet() -> bool:
	return true


func _hp_threshold() -> int:
	return get_upgrade_value_at("hp_threshold")


func _block_amount() -> int:
	return get_upgrade_value_at("block")


func get_upgrade_pick_description_bbcode() -> String:
	return tooltip_text % [
		bbcode_upgrade_pick_digit("hp_threshold", _hp_threshold()),
		bbcode_upgrade_pick_digit("block", _block_amount()),
	]


func get_default_tooltip() -> String:
	return tooltip_text % [_hp_threshold(), _block_amount()]


func get_updated_tooltip(
	_player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler, _combat_player: Node = null
) -> String:
	var hp_bb := bbcode_for_modified_number_with_upgrade_hint(
		_hp_threshold(), _hp_threshold(), is_upgrade_track_maxed("hp_threshold")
	)
	var intrinsic_b := _block_amount()
	var block_bb := bbcode_for_modified_number_with_upgrade_hint(
		effective_block_from_card_play(intrinsic_b, _combat_player),
		intrinsic_b,
		is_upgrade_track_maxed("block")
	)
	return tooltip_text % [hp_bb, block_bb]


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var block_effect := BlockEffect.new()
	block_effect.amount = _block_amount()
	block_effect.from_card_play = true
	block_effect.execute(targets)
