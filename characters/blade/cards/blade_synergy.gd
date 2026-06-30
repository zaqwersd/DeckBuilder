extends Card

const CARD_FREE_STATUS := preload("res://statuses/card_free.tres")
const BASE_DAMAGE := 22


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["cost"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	if track_id == "cost":
		return PackedInt32Array([3, 2])
	return PackedInt32Array()


func sync_unlocked_intrinsic_flags_from_upgrade_tracks() -> void:
	cost = get_upgrade_value_at("cost")


func get_upgrade_pick_description_bbcode() -> String:
	return "[center]造成%d点伤害。[br]本回合的下一张牌可以免费打出。[/center]" % BASE_DAMAGE


func _intrinsic_damage() -> int:
	return BASE_DAMAGE


func get_default_tooltip() -> String:
	return "造成%s点伤害。本回合的下一张牌可以免费打出。" % _intrinsic_damage()


func get_updated_tooltip(
	player_modifiers: ModifierHandler, enemy_modifiers: ModifierHandler, combat_player: Node = null
) -> String:
	var intrinsic := _intrinsic_damage()
	var dmg_bb := bbcode_for_modified_number_with_upgrade_hint(
		compute_attack_damage_dealt(intrinsic, player_modifiers, enemy_modifiers, combat_player),
		intrinsic,
		true
	)
	return "[center]造成%s点伤害。[br]本回合的下一张牌可以免费打出。[/center]" % dmg_bb


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
	var player := _get_combat_player_for_effects(targets)

	var damage_effect := DamageEffect.new()
	damage_effect.amount = resolve_attack_damage_dealt(
		_intrinsic_damage(), modifiers, player
	)
	damage_effect.sound = sound
	damage_effect.execute(targets)

	if not player or not player.get("status_handler"):
		return
	var status_effect := StatusEffect.new()
	var st := CARD_FREE_STATUS.duplicate()
	st.stacks = 1
	status_effect.status = st
	status_effect.execute([player])