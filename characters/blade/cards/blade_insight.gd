extends Card

const EXPOSED_STATUS = preload("res://statuses/exposed.tres")


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["exposed_duration"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	if track_id == "exposed_duration":
		return PackedInt32Array([2, 3])
	return PackedInt32Array()


func _intrinsic_exposed_duration() -> int:
	return get_upgrade_value_at("exposed_duration")


func get_upgrade_pick_description_bbcode() -> String:
	var ex := get_upgrade_value_at("exposed_duration")
	return "[center]给予%s层易伤。[br]消耗。[/center]" % [
		bbcode_upgrade_pick_digit("exposed_duration", ex),
	]


func _exposed_bbcode() -> String:
	var ed := _intrinsic_exposed_duration()
	return bbcode_for_modified_number_with_upgrade_hint(
		ed, ed, is_upgrade_track_maxed("exposed_duration")
	)


func get_default_tooltip() -> String:
	return tooltip_text % [_exposed_bbcode()]


func get_updated_tooltip(
	_player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler, _combat_player: Node = null
) -> String:
	return tooltip_text % [_exposed_bbcode()]


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var status_effect := StatusEffect.new()
	var exposed := EXPOSED_STATUS.duplicate()
	exposed.duration = _intrinsic_exposed_duration()
	status_effect.status = exposed
	status_effect.execute(targets)
