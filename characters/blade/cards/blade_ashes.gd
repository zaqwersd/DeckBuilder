extends Card

const _HIT_DELAY_SEC := 0.12
const _PER_HIT_DAMAGE := 6
const _EFFECT_BODY := "你的消耗堆每有一张牌，对所有敌人造成%s点伤害1次。"
const _EXHAUST_LINE := "消耗。"


func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["exhaust_line"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	if track_id == "exhaust_line":
		return PackedInt32Array([0, 0])
	return PackedInt32Array()


func _exhaust_line_bbcode() -> String:
	if not exhausts:
		return ""
	return _EXHAUST_LINE


func _append_exhaust_line_bbcode(body: String) -> String:
	var line := _exhaust_line_bbcode()
	if line.is_empty():
		return body
	return "%s%s" % [body, line]


func _wrap_center(body: String) -> String:
	return "[center]%s[/center]" % body


func _effect_body_bbcode(damage_bb: String) -> String:
	return _EFFECT_BODY % damage_bb


func get_upgrade_pick_description_bbcode() -> String:
	return _wrap_center(
		_append_exhaust_line_bbcode(_effect_body_bbcode(str(_PER_HIT_DAMAGE)))
	)


func _apply_upgraded_state() -> void:
	super._apply_upgraded_state()
	_sync_exhaust_from_upgrade()


func sync_unlocked_intrinsic_flags_from_upgrade_tracks() -> void:
	cost = 2
	_sync_exhaust_from_upgrade()


func _sync_exhaust_from_upgrade() -> void:
	var ch := get_upgrade_chain("exhaust_line")
	if ch.is_empty():
		return
	exhausts = not is_upgrade_track_maxed("exhaust_line")


func _per_hit_damage() -> int:
	return _PER_HIT_DAMAGE


func get_default_tooltip() -> String:
	return _wrap_center(
		_append_exhaust_line_bbcode(_effect_body_bbcode(str(_per_hit_damage())))
	)


func get_updated_tooltip(
	player_modifiers: ModifierHandler, enemy_modifiers: ModifierHandler, combat_player: Node = null
) -> String:
	var d_base := _per_hit_damage()
	var dmg_bb := bbcode_for_modified_number_with_upgrade_hint(
		compute_attack_damage_dealt(d_base, player_modifiers, enemy_modifiers, combat_player),
		d_base,
		true
	)
	return _wrap_center(_append_exhaust_line_bbcode(_effect_body_bbcode(dmg_bb)))


func get_combat_effect_summary_bbcode(
	player_modifiers: ModifierHandler,
	enemy_modifiers: ModifierHandler,
	combat_player: Node = null
) -> String:
	var d_base := _per_hit_damage()
	var m := compute_attack_damage_dealt(d_base, player_modifiers, enemy_modifiers, combat_player)
	var m_bb := bbcode_for_modified_number(m, d_base)
	var n := _exhaust_card_count(combat_player)
	return "(造成%s点伤害%d次。)" % [m_bb, n]


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
	var hit_count := _exhaust_card_count(_get_combat_player_for_effects(targets))
	if hit_count <= 0:
		return
	var per_hit := resolve_attack_damage_dealt(
		_per_hit_damage(), modifiers, _get_combat_player_for_effects(targets)
	)
	var tree: SceneTree = null
	for t: Node in targets:
		if is_instance_valid(t) and t.is_inside_tree():
			tree = t.get_tree()
			break
	if tree == null:
		tree = Engine.get_main_loop() as SceneTree
	for i: int in range(hit_count):
		if tree == null:
			break
		var alive := _get_alive_enemies(tree)
		if alive.is_empty():
			break
		var damage_effect := DamageEffect.new()
		damage_effect.amount = per_hit
		damage_effect.sound = sound
		damage_effect.execute(alive)
		if i < hit_count - 1:
			await tree.create_timer(_HIT_DELAY_SEC).timeout


func _exhaust_card_count(combat_player: Node) -> int:
	if combat_player is Player:
		var stats := (combat_player as Player).stats
		if stats != null and stats.exhaust != null:
			return stats.exhaust.cards.size()
	return 0


func _get_alive_enemies(tree: SceneTree) -> Array[Node]:
	var out: Array[Node] = []
	if tree == null:
		return out
	for enemy in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if not enemy is Enemy:
			continue
		var e := enemy as Enemy
		if e.stats != null and e.stats.health > 0:
			out.append(enemy)
	return out
