extends Card


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["block"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	if track_id == "block":
		return PackedInt32Array([5, 8, 11])
	return PackedInt32Array()


func get_upgrade_pick_description_bbcode() -> String:
	var v := get_upgrade_value_at("block")
	return "[center]获得%s点格挡。[/center]" % bbcode_upgrade_pick_digit("block", v)


func _intrinsic_block() -> int:
	return get_upgrade_value_at("block")


func get_default_tooltip() -> String:
	return tooltip_text % _intrinsic_block()


func get_updated_tooltip(
	_player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler, _combat_player: Node = null
) -> String:
	var b := _intrinsic_block()
	var mx := is_upgrade_track_maxed("block")
	return tooltip_text % bbcode_for_modified_number_with_upgrade_hint(b, b, mx)


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var block_effect := BlockEffect.new()
	block_effect.amount = _intrinsic_block()
	block_effect.sound = sound
	block_effect.execute(targets)
