class_name ExposedStatus
extends Status

const MODIFIER := 0.5


static func is_active_on(player: Player) -> bool:
	if player == null or player.status_handler == null:
		return false
	var st := player.status_handler.get_status_by_id("exposed")
	return st != null and st.duration > 0 and not st.awaits_turn_start


static func sync_modifier_with_status(player: Player) -> void:
	if player == null or player.modifier_handler == null:
		return
	var dmg_taken_modifier: Modifier = player.modifier_handler.get_modifier(Modifier.Type.DMG_TAKEN)
	if dmg_taken_modifier == null:
		return
	var st := player.status_handler.get_status_by_id("exposed") if player.status_handler else null
	var active := st != null and st.duration > 0 and not st.awaits_turn_start
	if active:
		st.initialize_status(player)
	elif dmg_taken_modifier.get_value("exposed") != null:
		dmg_taken_modifier.remove_value("exposed")


func get_tooltip() -> String:
	return tooltip % format_counter_for_tooltip(duration)


func initialize_status(target: Node) -> void:
	assert(target.get("modifier_handler"), "No modifiers on %s" % target)
	
	var dmg_taken_modifier: Modifier = target.modifier_handler.get_modifier(Modifier.Type.DMG_TAKEN)
	assert(dmg_taken_modifier, "No dmg taken modifier on %s" % target)

	var exposed_modifier_value := dmg_taken_modifier.get_value("exposed")

	if not exposed_modifier_value:
		exposed_modifier_value = ModifierValue.create_new_modifier("exposed", ModifierValue.Type.PERCENT_BASED)
		exposed_modifier_value.percent_value = MODIFIER
		dmg_taken_modifier.add_new_value(exposed_modifier_value)
	
	if not status_changed.is_connected(_on_status_changed):
		status_changed.connect(_on_status_changed.bind(dmg_taken_modifier))


func _on_status_changed(dmg_taken_modifier: Modifier) -> void:
	if duration <= 0 and dmg_taken_modifier:
		dmg_taken_modifier.remove_value("exposed")
		_emit_player_combat_stat_if_ready()


func deactivate_status(target: Node) -> void:
	if not target.get("modifier_handler"):
		return
	var dmg_taken_modifier: Modifier = target.modifier_handler.get_modifier(Modifier.Type.DMG_TAKEN)
	if dmg_taken_modifier == null or dmg_taken_modifier.get_value("exposed") == null:
		return
	dmg_taken_modifier.remove_value("exposed")
	_emit_player_combat_stat_if_ready()


static func _emit_player_combat_stat_if_ready() -> void:
	if Events.is_player_turn_start_resolving():
		return
	Events.player_combat_stat_context_changed.emit()
