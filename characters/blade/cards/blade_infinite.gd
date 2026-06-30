extends Card

const INFINITE_STATUS := preload("res://statuses/infinite_state.tres")
const _DESCRIPTION := "[center]每当有一张牌被消耗，获得1点能量。[/center]"


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["cost"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	if track_id == "cost":
		return PackedInt32Array([3, 2])
	return PackedInt32Array()


func sync_unlocked_intrinsic_flags_from_upgrade_tracks() -> void:
	cost = get_upgrade_value_at("cost")


func get_upgrade_pick_description_bbcode() -> String:
	return _DESCRIPTION


func get_default_tooltip() -> String:
	return _DESCRIPTION


func get_updated_tooltip(
	_player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler, _combat_player: Node = null
) -> String:
	return _DESCRIPTION


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var status_effect := StatusEffect.new()
	var st := INFINITE_STATUS.duplicate()
	st.stacks = 1
	status_effect.status = st
	status_effect.execute(targets)
