extends Card

const VULNERABLE_STATUS = preload("res://statuses/vulnerable.tres")


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["vulnerable_duration"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	if track_id == "vulnerable_duration":
		return PackedInt32Array([2, 3])
	return PackedInt32Array()


func _intrinsic_vulnerable_duration() -> int:
	return get_upgrade_value_at("vulnerable_duration")


func get_upgrade_pick_description_bbcode() -> String:
	var ex := get_upgrade_value_at("vulnerable_duration")
	return "[center]给予%s层易伤。[br]消耗。[/center]" % [
		bbcode_upgrade_pick_digit("vulnerable_duration", ex),
	]


func _vulnerable_bbcode() -> String:
	var ed := _intrinsic_vulnerable_duration()
	return bbcode_for_modified_number_with_upgrade_hint(
		ed, ed, is_upgrade_track_maxed("vulnerable_duration")
	)


func get_default_tooltip() -> String:
	return tooltip_text % [_vulnerable_bbcode()]


func get_updated_tooltip(
	_player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler, _combat_player: Node = null
) -> String:
	return tooltip_text % [_vulnerable_bbcode()]


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var status_effect := StatusEffect.new()
	var vulnerable := VULNERABLE_STATUS.duplicate()
	vulnerable.duration = _intrinsic_vulnerable_duration()
	status_effect.status = vulnerable
	status_effect.execute(targets)
