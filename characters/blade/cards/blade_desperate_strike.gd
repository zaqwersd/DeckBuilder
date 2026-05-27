extends Card

const SELF_DAMAGE := 6


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["damage"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	if track_id == "damage":
		return PackedInt32Array([12, 15, 20])
	return PackedInt32Array()


func get_upgrade_pick_description_bbcode() -> String:
	var dmg := get_upgrade_value_at("damage")
	return "[center]受到%d点伤害。[br]造成%s点伤害。[/center]" % [
		SELF_DAMAGE,
		bbcode_upgrade_pick_digit("damage", dmg),
	]


func _intrinsic_damage() -> int:
	return get_upgrade_value_at("damage")


func get_default_tooltip() -> String:
	return tooltip_text % [_intrinsic_damage()]


func get_updated_tooltip(
	player_modifiers: ModifierHandler, enemy_modifiers: ModifierHandler, combat_player: Node = null
) -> String:
	var intrinsic := _intrinsic_damage()
	var mx := is_upgrade_track_maxed("damage")
	return tooltip_text % [
		bbcode_for_modified_number_with_upgrade_hint(
			compute_attack_damage_dealt(intrinsic, player_modifiers, enemy_modifiers, combat_player),
			intrinsic,
			mx
		)
	]


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		var players := tree.get_nodes_in_group("player")
		if not players.is_empty():
			var player := players[0] as Player
			if player:
				## 与敌人伤害相同：经格挡结算；不经玩家 DMG_TAKEN，故不受易伤影响。
				player.take_damage_final(SELF_DAMAGE)

	var damage_effect := DamageEffect.new()
	damage_effect.amount = resolve_attack_damage_dealt(
		_intrinsic_damage(), modifiers, _get_combat_player_for_effects(targets)
	)
	damage_effect.sound = sound
	damage_effect.execute(targets)
