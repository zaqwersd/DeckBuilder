class_name FrailStatus
extends Status

const MODIFIER := -0.25


func get_tooltip() -> String:
	return tooltip % format_counter_for_tooltip(duration)


func initialize_status(target: Node) -> void:
	assert(target is Player, "Frail only applies to player")
	assert(target.get("modifier_handler"), "No modifiers on %s" % target)
	var block_gained_modifier: Modifier = target.modifier_handler.get_modifier(Modifier.Type.BLOCK_GAINED)
	assert(block_gained_modifier, "No block gained modifier on %s" % target)
	var frail_modifier_value := block_gained_modifier.get_value("frail")
	if not frail_modifier_value:
		frail_modifier_value = ModifierValue.create_new_modifier("frail", ModifierValue.Type.PERCENT_BASED)
		frail_modifier_value.percent_value = MODIFIER
		block_gained_modifier.add_new_value(frail_modifier_value)
	if not status_changed.is_connected(_on_status_changed):
		status_changed.connect(_on_status_changed.bind(block_gained_modifier))
	_emit_player_combat_stat_if_ready()


func _on_status_changed(block_gained_modifier: Modifier) -> void:
	if duration <= 0 and block_gained_modifier:
		if block_gained_modifier.get_value("frail") != null:
			block_gained_modifier.remove_value("frail")
			_emit_player_combat_stat_if_ready()


func deactivate_status(target: Node) -> void:
	if not target is Player:
		return
	var block_gained_modifier: Modifier = target.modifier_handler.get_modifier(Modifier.Type.BLOCK_GAINED)
	if block_gained_modifier == null or block_gained_modifier.get_value("frail") == null:
		return
	block_gained_modifier.remove_value("frail")
	_emit_player_combat_stat_if_ready()


static func _emit_player_combat_stat_if_ready() -> void:
	if Events.is_player_turn_start_resolving():
		return
	Events.player_combat_stat_context_changed.emit()
