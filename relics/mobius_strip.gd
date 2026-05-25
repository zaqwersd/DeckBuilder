extends Relic

var relic_ui: RelicUI


func initialize_relic(owner: RelicUI) -> void:
	relic_ui = owner
	Events.deck_shuffled.connect(_on_deck_shuffled)


func deactivate_relic(_owner: RelicUI) -> void:
	if Events.deck_shuffled.is_connected(_on_deck_shuffled):
		Events.deck_shuffled.disconnect(_on_deck_shuffled)


func _on_deck_shuffled() -> void:
	if not is_instance_valid(relic_ui):
		return
	var tree := relic_ui.get_tree()
	if tree == null or Events.is_combat_ended():
		return
	var player_handler := tree.get_first_node_in_group("player_handler") as PlayerHandler
	if player_handler == null:
		return
	relic_ui.flash()
	player_handler.request_shuffle_bonus_draw(1)
