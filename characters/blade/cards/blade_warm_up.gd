extends Card

const WARM_UP_STATUS := preload("res://statuses/offense_and_defense_in_one.tres")


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["cost"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	if track_id == "cost":
		return PackedInt32Array([1, 0])
	return PackedInt32Array()


func sync_unlocked_intrinsic_flags_from_upgrade_tracks() -> void:
	cost = get_upgrade_value_at("cost")


func should_visualize_cost_as_upgradeable() -> bool:
	return true


func get_upgrade_pick_description_bbcode() -> String:
	return tooltip_text


func get_default_tooltip() -> String:
	return tooltip_text


func get_updated_tooltip(
	_player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler, _combat_player: Node = null
) -> String:
	return tooltip_text


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var status_effect := StatusEffect.new()
	var st := WARM_UP_STATUS.duplicate(true) as OffenseAndDefenseInOneStatus
	if st == null:
		return
	status_effect.status = st
	status_effect.execute(targets)
