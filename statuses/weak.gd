class_name WeakStatus
extends Status

const MODIFIER := -0.25
const ATTACK_DAMAGE_MULTIPLIER := 0.75


func get_tooltip() -> String:
	return tooltip % format_counter_for_tooltip(duration)


func initialize_status(target: Node) -> void:
	if target is Player:
		if not status_changed.is_connected(_on_player_weak_changed):
			status_changed.connect(_on_player_weak_changed)
		_notify_combat_stat_context_changed()
		return
	_configure_enemy_turn_longevity()
	assert(target.get("modifier_handler"), "No modifiers on %s" % target)
	var dmg_dealt_modifier: Modifier = target.modifier_handler.get_modifier(Modifier.Type.DMG_DEALT)
	assert(dmg_dealt_modifier, "No dmg dealt modifier on %s" % target)
	var weak_modifier_value := dmg_dealt_modifier.get_value("weak")
	if not weak_modifier_value:
		weak_modifier_value = ModifierValue.create_new_modifier("weak", ModifierValue.Type.PERCENT_BASED)
		weak_modifier_value.percent_value = MODIFIER
		dmg_dealt_modifier.add_new_value(weak_modifier_value)
	if not status_changed.is_connected(_on_enemy_weak_changed):
		status_changed.connect(_on_enemy_weak_changed.bind(dmg_dealt_modifier, target))
	if target is Enemy:
		(target as Enemy).update_intent()


func _on_player_weak_changed() -> void:
	WeakStatus._notify_combat_stat_context_changed()


func _on_enemy_weak_changed(dmg_dealt_modifier: Modifier, enemy: Node) -> void:
	if duration <= 0 and dmg_dealt_modifier:
		dmg_dealt_modifier.remove_value("weak")
	if enemy is Enemy:
		(enemy as Enemy).update_intent()


static func has_weak(owner: Node) -> bool:
	return is_active_on(owner)


static func is_active_on(owner: Node) -> bool:
	if owner == null:
		return false
	var status_handler: StatusHandler = owner.get("status_handler")
	if status_handler == null:
		return false
	var st := status_handler.get_status_by_id("weak")
	return st != null and st.duration > 0 and not st.awaits_turn_start


static func apply_to_attack_damage(damage: int, owner: Node) -> int:
	if damage <= 0 or not is_active_on(owner):
		return damage
	return maxi(0, floori(float(damage) * ATTACK_DAMAGE_MULTIPLIER))


func deactivate_status(target: Node) -> void:
	if target is Player:
		_notify_combat_stat_context_changed()
		return
	if not target.get("modifier_handler"):
		return
	var dmg_dealt_modifier: Modifier = target.modifier_handler.get_modifier(Modifier.Type.DMG_DEALT)
	if dmg_dealt_modifier:
		dmg_dealt_modifier.remove_value("weak")
	if target is Enemy:
		(target as Enemy).update_intent()


static func _notify_combat_stat_context_changed() -> void:
	if Events.is_player_turn_start_resolving():
		return
	Events.player_combat_stat_context_changed.emit()


func _configure_enemy_turn_longevity() -> void:
	type = Status.Type.EVENT_BASED
	ticks_on_player_turn_start_on_enemy = true
