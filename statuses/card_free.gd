class_name CardFreeStatus
extends Status


func initialize_status(target: Node) -> void:
	if target is Player:
		_connect_combat_signals()


func deactivate_status(_target: Node) -> void:
	_disconnect_combat_signals()


func get_tooltip() -> String:
	return tooltip % format_counter_for_tooltip(stacks)


func _connect_combat_signals() -> void:
	if not Events.card_played.is_connected(_on_card_played):
		Events.card_played.connect(_on_card_played)
	if not Events.player_turn_ended.is_connected(_on_player_turn_ended):
		Events.player_turn_ended.connect(_on_player_turn_ended)


func _disconnect_combat_signals() -> void:
	if Events.card_played.is_connected(_on_card_played):
		Events.card_played.disconnect(_on_card_played)
	if Events.player_turn_ended.is_connected(_on_player_turn_ended):
		Events.player_turn_ended.disconnect(_on_player_turn_ended)


func _on_card_played(_card: Card) -> void:
	if stacks <= 0:
		return
	set_stacks(maxi(0, stacks - 1))
	Events.player_hand_cost_context_changed.emit()


func _on_player_turn_ended() -> void:
	if stacks <= 0:
		return
	set_stacks(0)
	Events.player_hand_cost_context_changed.emit()


static func stacks_on_player(player: Player) -> int:
	if player == null or player.status_handler == null:
		return 0
	var st := player.status_handler.get_status_by_id("card_free")
	return st.stacks if st else 0


static func makes_next_card_free(player: Player) -> bool:
	return stacks_on_player(player) > 0


static func consume_one_if_present(player: Player) -> void:
	if player == null or player.status_handler == null:
		return
	var st := player.status_handler.get_status_by_id("card_free")
	if st == null or st.stacks <= 0:
		return
	st.set_stacks(maxi(0, st.stacks - 1))
	Events.player_hand_cost_context_changed.emit()
