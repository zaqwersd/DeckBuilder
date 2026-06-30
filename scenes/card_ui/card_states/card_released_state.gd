extends CardState


func enter() -> void:
	if not card_ui.validate_and_fill_play_targets():
		return

	var play_hand := card_ui._resolve_combat_hand()
	if play_hand != null and is_instance_valid(play_hand):
		play_hand.request_card_play(card_ui, card_ui.targets)


func post_enter() -> void:
	transition_requested.emit(self, CardState.State.BASE)
