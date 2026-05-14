extends Card


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["cost", "damage", "exhaust_line"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	match track_id:
		"cost":
			return PackedInt32Array([1, 0])
		"damage":
			return PackedInt32Array([8, 10])
		"exhaust_line":
			return PackedInt32Array([0, 0])
		_:
			return PackedInt32Array()


func get_upgrade_pick_description_bbcode() -> String:
	var dmg := get_upgrade_value_at("damage")
	var exhaust_str := _exhaust_line_bbcode()
	return "[center]造成%s点伤害。[br]抽1张牌。[br]%s[/center]" % [
		bbcode_upgrade_pick_digit("damage", dmg),
		exhaust_str
	]


func _exhaust_line_bbcode() -> String:
	if is_upgrade_track_maxed("exhaust_line"):
		return ""
	return "[url=ugp:exhaust_line][color=%s]消耗。[/color][/url]" % BB_UPGRADE_NEGATIVE_REMOVABLE


func increment_upgrade_track(track_id: String) -> void:
	super.increment_upgrade_track(track_id)
	if track_id == "cost":
		cost = _intrinsic_cost()
	# 当 exhaust_line 升级满后，去掉消耗属性
	if track_id == "exhaust_line" and is_upgrade_track_maxed("exhaust_line"):
		exhausts = false


func _intrinsic_cost() -> int:
	return get_upgrade_value_at("cost")


func should_visualize_cost_as_upgradeable() -> bool:
	var ch := get_upgrade_chain("cost")
	if ch.is_empty():
		return false
	return not is_upgrade_track_maxed("cost")


func get_visual_description_bbcode() -> String:
	return get_updated_visual_description_bbcode(null, null, null)


func get_updated_visual_description_bbcode(
	_player_modifiers: ModifierHandler,
	_enemy_modifiers: ModifierHandler,
	combat_player: Node = null
) -> String:
	var dmg := get_upgrade_value_at("damage")
	var dmg_bb := bbcode_for_modified_number_with_upgrade_hint(
		dmg, dmg, is_upgrade_track_maxed("damage")
	)
	
	# 未升级时显示红色"消耗"，表示可通过升级去掉
	var exhaust_bb := ""
	if not is_upgrade_track_maxed("exhaust_line"):
		exhaust_bb = "[color=%s]消耗。[/color]" % BB_UPGRADE_NEGATIVE_REMOVABLE
	
	return "[center]造成%s点伤害。[br]抽1张牌。[br]%s[/center]" % [dmg_bb, exhaust_bb]


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
	var dmg := get_upgrade_value_at("damage")
	var damage_effect := DamageEffect.new()
	damage_effect.amount = modifiers.get_modified_value(dmg, Modifier.Type.DMG_DEALT)
	damage_effect.sound = sound
	damage_effect.execute(targets)

	var card_draw_effect := CardDrawEffect.new()
	card_draw_effect.cards_to_draw = 1
	card_draw_effect.execute(targets)
