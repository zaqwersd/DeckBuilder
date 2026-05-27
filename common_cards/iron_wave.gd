extends Card


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["block", "damage"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	if track_id == "block" or track_id == "damage":
		return PackedInt32Array([6, 9, 13])
	return PackedInt32Array()


func get_upgrade_pick_description_bbcode() -> String:
	var b := get_upgrade_value_at("block")
	var d := get_upgrade_value_at("damage")
	return "[center]获得%s点格挡。[br]造成%s点伤害。[/center]" % [
		bbcode_upgrade_pick_digit("block", b),
		bbcode_upgrade_pick_digit("damage", d),
	]


func _intrinsic_block() -> int:
	return get_upgrade_value_at("block")


func _intrinsic_damage() -> int:
	return get_upgrade_value_at("damage")


func get_visual_description_bbcode() -> String:
	return get_updated_visual_description_bbcode(null, null)


func get_default_tooltip() -> String:
	return tooltip_text % [_intrinsic_block(), _intrinsic_damage()]


func get_updated_tooltip(
	player_modifiers: ModifierHandler, enemy_modifiers: ModifierHandler, combat_player: Node = null
) -> String:
	var ib := _intrinsic_block()
	var idmg := _intrinsic_damage()
	var dmg_bb := bbcode_for_modified_number_with_upgrade_hint(
		compute_attack_damage_dealt(idmg, player_modifiers, enemy_modifiers, combat_player),
		idmg,
		is_upgrade_track_maxed("damage")
	)
	var block_bb := bbcode_for_modified_number_with_upgrade_hint(
		effective_block_from_card_play(ib, combat_player), ib, is_upgrade_track_maxed("block")
	)
	return tooltip_text % [block_bb, dmg_bb]


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
	var tree: SceneTree = null
	for t: Node in targets:
		if is_instance_valid(t) and t.is_inside_tree():
			tree = t.get_tree()
			break
	var player_nodes: Array[Node] = []
	if tree:
		player_nodes.append_array(tree.get_nodes_in_group("player"))
	var block_effect := BlockEffect.new()
	block_effect.amount = _intrinsic_block()
	block_effect.from_card_play = true
	block_effect.execute(player_nodes)
	var damage_effect := DamageEffect.new()
	damage_effect.amount = resolve_attack_damage_dealt(
		_intrinsic_damage(), modifiers, _get_combat_player_for_effects(targets)
	)
	damage_effect.sound = sound
	damage_effect.execute(targets)
