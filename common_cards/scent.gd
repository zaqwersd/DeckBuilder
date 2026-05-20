extends Card

## 遗香：公共 special 技能。保留，回复生命，消耗；治疗量 6→9 可升级一次。


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["heal"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	if track_id == "heal":
		return PackedInt32Array([6, 9])
	return PackedInt32Array()


func _heal_amount() -> int:
	return get_upgrade_value_at("heal")


func _heal_amount_bbcode() -> String:
	var amt := _heal_amount()
	return bbcode_for_modified_number_with_upgrade_hint(amt, amt, is_upgrade_track_maxed("heal"))


func get_upgrade_pick_description_bbcode() -> String:
	return "[center]保留。[br]回复%s点生命。[br]消耗。[/center]" % bbcode_upgrade_pick_digit(
		"heal", get_upgrade_value_at("heal")
	)


func get_default_tooltip() -> String:
	return tooltip_text % [_heal_amount_bbcode()]


func get_updated_tooltip(
	_player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler, _combat_player: Node = null
) -> String:
	var heal_bb := _heal_amount_bbcode()
	return tooltip_text % [heal_bb]


func get_visual_description_bbcode() -> String:
	return get_updated_visual_description_bbcode(null, null)


func get_updated_visual_description_bbcode(
	_player_modifiers: ModifierHandler,
	_enemy_modifiers: ModifierHandler,
	_combat_player: Node = null
) -> String:
	return get_updated_tooltip(_player_modifiers, _enemy_modifiers, _combat_player)


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	for node: Node in targets:
		var stats: Stats = node.get("stats") as Stats
		if stats:
			stats.heal(_heal_amount())
