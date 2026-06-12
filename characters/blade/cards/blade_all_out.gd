extends Card


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["formula"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	if track_id == "formula":
		return PackedInt32Array([0, 1])
	return PackedInt32Array()


func _formula_tier() -> int:
	return get_upgrade_value_at("formula")


func _damage_mult() -> int:
	match _formula_tier():
		0:
			return 9
		1:
			return 13
		_:
			return 9


func _formula_display_plain() -> String:
	match _formula_tier():
		0:
			return "9X"
		1:
			return "13X"
		_:
			return "9X"


func _intrinsic_damage_for_x(x: int) -> int:
	return _damage_mult() * x


## 整条公式（9X / 12X / 16X）同色：战斗一律白字；局外可升级黄字，满级默认字色。
func _formula_bbcode_colored() -> String:
	var text := _formula_display_plain()
	if is_visual_number_bbcode_combat():
		return "[color=%s]%s[/color]" % [COMBAT_BODY_TEXT, text]
	if is_upgrade_track_maxed("formula"):
		return text
	return "[color=%s]%s[/color]" % [BB_COLOR_UPGRADEABLE, text]


func _formula_bbcode_upgrade_pick() -> String:
	var text := _formula_display_plain()
	if is_upgrade_track_maxed("formula"):
		return "[color=%s]%s[/color]" % [COMBAT_BODY_TEXT, text]
	return "[url=ugp:formula][color=%s]%s[/color][/url]" % [BB_UPGRADE_VALUE, text]


func get_upgrade_pick_description_bbcode() -> String:
	return "[center]造成%s点伤害。[/center]" % _formula_bbcode_upgrade_pick()


func get_default_tooltip() -> String:
	return get_visual_description_bbcode()


func get_visual_description_bbcode() -> String:
	return "[center]造成%s点伤害。[/center]" % _formula_bbcode_colored()


func get_updated_tooltip(
	player_modifiers: ModifierHandler, enemy_modifiers: ModifierHandler, combat_player: Node = null
) -> String:
	if is_visual_number_bbcode_combat():
		return _combat_body_bbcode(player_modifiers, enemy_modifiers, combat_player)
	return get_visual_description_bbcode()


func get_updated_visual_description_bbcode(
	player_modifiers: ModifierHandler,
	enemy_modifiers: ModifierHandler,
	combat_player: Node = null
) -> String:
	var body := get_updated_tooltip(player_modifiers, enemy_modifiers, combat_player)
	return _bbcode_visible_line_breaks(body)


func _combat_body_bbcode(
	player_modifiers: ModifierHandler,
	enemy_modifiers: ModifierHandler,
	combat_player: Node = null
) -> String:
	var formula_bb := _formula_bbcode_colored()
	var char_stats: CharacterStats = null
	if combat_player is Player:
		char_stats = (combat_player as Player).stats
	var preview_x := 0
	if char_stats:
		preview_x = PlayCostResolver.compute_mana_to_spend(
			self, char_stats, combat_player, player_modifiers
		)
	var intrinsic := _intrinsic_damage_for_x(preview_x)
	var dmg_bb := bbcode_for_modified_number_with_upgrade_hint(
		compute_attack_damage_dealt(intrinsic, player_modifiers, enemy_modifiers, combat_player),
		intrinsic,
		is_upgrade_track_maxed("formula")
	)
	return "[center]造成%s点伤害。[br](造成%s点伤害)[/center]" % [formula_bb, dmg_bb]


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
	var x := get_play_x()
	var base := _intrinsic_damage_for_x(x)
	var damage_effect := DamageEffect.new()
	damage_effect.amount = resolve_attack_damage_dealt(
		base, modifiers, _get_combat_player_for_effects(targets)
	)
	damage_effect.sound = sound
	damage_effect.execute(targets)
