extends Card

const MALICE_STATUS := preload("res://statuses/malice_state.tres")


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["m"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	match track_id:
		"m":
			return PackedInt32Array([15, 20])
		_:
			return PackedInt32Array()


func get_upgrade_pick_description_bbcode() -> String:
	var m_val := get_upgrade_value_at("m")
	return "[center]敌人每有一层易伤，额外受到%s%%伤害。[/center]" % (
		bbcode_upgrade_pick_digit("m", m_val)
	)


func sync_unlocked_intrinsic_flags_from_upgrade_tracks() -> void:
	intrinsic = false


func _apply_upgraded_state() -> void:
	super._apply_upgraded_state()
	intrinsic = false


func get_visual_description_bbcode() -> String:
	return get_updated_visual_description_bbcode(null, null, null)


func get_updated_visual_description_bbcode(
	_player_modifiers: ModifierHandler,
	_enemy_modifiers: ModifierHandler,
	combat_player: Node = null
) -> String:
	var m_val := get_upgrade_value_at("m")
	var m_bb := bbcode_for_modified_number_with_upgrade_hint(
		m_val, m_val, is_upgrade_track_maxed("m")
	)
	return "[center]敌人每有一层易伤，额外受到%s%%伤害。[/center]" % m_bb


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var status_effect := StatusEffect.new()
	var st := MALICE_STATUS.duplicate()
	st.m = get_upgrade_value_at("m")
	status_effect.status = st
	status_effect.execute(targets)
