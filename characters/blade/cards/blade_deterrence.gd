extends Card

const DETERRENCE_STATUS := preload("res://statuses/deterrence_state.tres")
const STRENGTH_GAIN := 1


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["intrinsic"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	if track_id == "intrinsic":
		return PackedInt32Array([0, 0])
	return PackedInt32Array()


func sync_unlocked_intrinsic_flags_from_upgrade_tracks() -> void:
	intrinsic = is_upgraded


func _body_text() -> String:
	return "每回合结束时获得%d点%s，然后对所有敌人造成等于你当前%s的伤害。" % [
		STRENGTH_GAIN,
		CardKeywordTokens.bb_mechanic_link("力量", "strength"),
		CardKeywordTokens.bb_mechanic_link("力量", "strength"),
	]


func _description() -> String:
	return "[center]%s[/center]" % _body_text()


func get_upgrade_pick_description_bbcode() -> String:
	return "[center]%s[br]%s[/center]" % [
		CardKeywordTokens.bb_mechanic_link("固有。", "intrinsic"),
		_body_text(),
	]


func get_default_tooltip() -> String:
	return _description()


func get_updated_tooltip(
	_player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler, _combat_player: Node = null
) -> String:
	return _description()


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var status_effect := StatusEffect.new()
	var st := DETERRENCE_STATUS.duplicate() as DeterrenceStatus
	if st == null:
		return
	st.stacks = STRENGTH_GAIN
	status_effect.status = st
	status_effect.execute(targets)
