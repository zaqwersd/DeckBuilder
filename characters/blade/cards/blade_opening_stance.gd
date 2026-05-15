extends Card


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["energy_gain"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	if track_id == "energy_gain":
		return PackedInt32Array([4, 5, 6])
	return PackedInt32Array()


func _energy_gain() -> int:
	return get_upgrade_value_at("energy_gain")


func get_upgrade_pick_description_bbcode() -> String:
	var v := _energy_gain()
	return "[center]获得%s点能量。[/center]" % bbcode_upgrade_pick_digit("energy_gain", v)


func get_default_tooltip() -> String:
	return get_upgrade_pick_description_bbcode()


func get_updated_tooltip(
	_player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler, _combat_player: Node = null
) -> String:
	var v := _energy_gain()
	if is_visual_number_bbcode_combat():
		var mx := is_upgrade_track_maxed("energy_gain")
		var col := COMBAT_BODY_TEXT if mx else BB_COLOR_UPGRADEABLE
		return "[center]获得[color=%s]%d[/color]点能量。[/center]" % [col, v]
	var mx2 := is_upgrade_track_maxed("energy_gain")
	var num_bb := bbcode_for_modified_number_with_upgrade_hint(v, v, mx2)
	return "[center]获得%s点能量。[/center]" % num_bb


func plays_card_sound_on_play() -> bool:
	return true


func apply_effects(_targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var ph := tree.get_first_node_in_group("player_handler") as PlayerHandler
	if ph == null or ph.character == null:
		return
	ph.character.mana += _energy_gain()
