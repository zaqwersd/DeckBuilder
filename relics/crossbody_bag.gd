extends Relic

@export var extra_draw := 2


func activate_relic(owner: RelicUI) -> void:
	Events.player_hand_drawn.connect(_draw_extra.bind(owner), CONNECT_ONE_SHOT)


func _draw_extra(owner: RelicUI) -> void:
	if not is_instance_valid(owner):
		return
	var tree := owner.get_tree()
	if tree == null:
		return
	var player_handler := tree.get_first_node_in_group("player_handler") as PlayerHandler
	if player_handler == null:
		return
	player_handler.draw_cards(extra_draw)
	owner.flash()
