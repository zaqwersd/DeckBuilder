extends Card

const _PER_HIT_DELAY_SEC := 0.2


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["damage", "hits"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	match track_id:
		"damage":
			return PackedInt32Array([3, 4])
		"hits":
			return PackedInt32Array([3, 4])
		_:
			return PackedInt32Array()


func get_upgrade_pick_description_bbcode() -> String:
	var d := get_upgrade_value_at("damage")
	var h := get_upgrade_value_at("hits")
	return "[center]造成%s点伤害%s次。[/center]" % [
		bbcode_upgrade_pick_digit("damage", d),
		bbcode_upgrade_pick_digit("hits", h),
	]


func _per_hit_damage() -> int:
	return get_upgrade_value_at("damage")


func _hit_count() -> int:
	return get_upgrade_value_at("hits")


func get_default_tooltip() -> String:
	return tooltip_text % [str(_per_hit_damage()), str(_hit_count())]


func get_updated_tooltip(
	player_modifiers: ModifierHandler, enemy_modifiers: ModifierHandler, combat_player: Node = null
) -> String:
	var d_base := _per_hit_damage()
	var modified_dmg := d_base
	if player_modifiers:
		modified_dmg = player_modifiers.get_modified_value(d_base, Modifier.Type.DMG_DEALT)
	if enemy_modifiers:
		modified_dmg = enemy_modifiers.get_modified_value(modified_dmg, Modifier.Type.DMG_TAKEN)
	modified_dmg = OverwhelmingStatus.apply_to_attack_card_preview_damage(combat_player, modified_dmg, type)
	var dmg_bb := bbcode_for_modified_number_with_upgrade_hint(
		modified_dmg, d_base, is_upgrade_track_maxed("damage")
	)
	var h_base := _hit_count()
	var hits_bb := bbcode_for_modified_number_with_upgrade_hint(
		h_base, h_base, is_upgrade_track_maxed("hits")
	)
	return "[center]造成%s点伤害%s次。[/center]" % [dmg_bb, hits_bb]


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
	var per := modifiers.get_modified_value(_per_hit_damage(), Modifier.Type.DMG_DEALT)
	var n := _hit_count()
	var tree: SceneTree = null
	for t in targets:
		if is_instance_valid(t) and t.is_inside_tree():
			tree = t.get_tree()
			break
	if tree == null:
		tree = Engine.get_main_loop() as SceneTree
	for i in range(n):
		var damage_effect := DamageEffect.new()
		damage_effect.amount = per
		damage_effect.sound = sound
		damage_effect.execute(targets)
		if i < n - 1 and tree != null:
			await tree.create_timer(_PER_HIT_DELAY_SEC).timeout
