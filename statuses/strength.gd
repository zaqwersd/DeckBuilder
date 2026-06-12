class_name MuscleStatus
extends Status

var _status_sync_handler: Callable = Callable()


func get_tooltip() -> String:
	return tooltip % format_counter_for_tooltip(stacks)


func initialize_status(target: Node) -> void:
	if _status_sync_handler.is_null():
		_status_sync_handler = _on_status_changed.bind(target)
	if not status_changed.is_connected(_status_sync_handler):
		status_changed.connect(_status_sync_handler)
	_on_status_changed(target)


func _on_status_changed(target: Node) -> void:
	assert(target.get("modifier_handler"), "No modifiers on %s" % target)

	var dmg_dealt_modifier: Modifier = target.modifier_handler.get_modifier(Modifier.Type.DMG_DEALT)
	assert(dmg_dealt_modifier, "No dmg dealt modifier on %s" % target)

	if stacks == 0:
		dmg_dealt_modifier.remove_value("muscle")
		_notify_combat_context_changed(target)
		return

	var muscle_modifier_value := dmg_dealt_modifier.get_value("muscle")

	if not muscle_modifier_value:
		muscle_modifier_value = ModifierValue.create_new_modifier("muscle", ModifierValue.Type.FLAT)

	muscle_modifier_value.flat_value = stacks
	dmg_dealt_modifier.add_new_value(muscle_modifier_value)
	_notify_combat_context_changed(target)


func deactivate_status(target: Node) -> void:
	if not target.get("modifier_handler"):
		return
	var dmg_dealt_modifier: Modifier = target.modifier_handler.get_modifier(Modifier.Type.DMG_DEALT)
	if dmg_dealt_modifier:
		dmg_dealt_modifier.remove_value("muscle")
	_notify_combat_context_changed(target)


static func _notify_combat_context_changed(target: Node) -> void:
	if Events.is_player_turn_start_resolving():
		return
	if target is Player:
		Events.player_combat_stat_context_changed.emit()
	elif target is Enemy:
		(target as Enemy).update_intent()
