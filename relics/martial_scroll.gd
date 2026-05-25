extends Relic

const MODIFIER_SOURCE := "martial_scroll"
const COST_REDUCTION := -1

var relic_ui: RelicUI


func initialize_relic(owner: RelicUI) -> void:
	relic_ui = owner
	if not Events.player_hand_drawn.is_connected(_ensure_modifier):
		Events.player_hand_drawn.connect(_ensure_modifier)
	_ensure_modifier()


func deactivate_relic(owner: RelicUI) -> void:
	if Events.player_hand_drawn.is_connected(_ensure_modifier):
		Events.player_hand_drawn.disconnect(_ensure_modifier)
	_remove_modifier(owner)


func _ensure_modifier() -> void:
	if not is_instance_valid(relic_ui):
		return
	var tree := relic_ui.get_tree()
	if tree == null:
		return
	var player := tree.get_first_node_in_group("player") as Player
	if player == null:
		return
	var power_cost_modifier := player.modifier_handler.get_modifier(Modifier.Type.POWER_CARD_COST)
	if power_cost_modifier == null:
		return
	var modifier_value := power_cost_modifier.get_value(MODIFIER_SOURCE)
	if modifier_value == null:
		modifier_value = ModifierValue.create_new_modifier(MODIFIER_SOURCE, ModifierValue.Type.FLAT)
		modifier_value.flat_value = COST_REDUCTION
		power_cost_modifier.add_new_value(modifier_value)
	Events.player_hand_cost_context_changed.emit()


func _remove_modifier(owner: RelicUI) -> void:
	if not is_instance_valid(owner):
		return
	var tree := owner.get_tree()
	if tree == null:
		return
	var player := tree.get_first_node_in_group("player") as Player
	if player == null:
		return
	var power_cost_modifier := player.modifier_handler.get_modifier(Modifier.Type.POWER_CARD_COST)
	if power_cost_modifier == null:
		return
	power_cost_modifier.remove_value(MODIFIER_SOURCE)
	Events.player_hand_cost_context_changed.emit()
