extends CardState


func enter() -> void:
	if not card_ui.char_stats.can_play_card(card_ui.card, card_ui.get_effective_mana_cost()):
		return
	if card_ui.targets.is_empty():
		return

	var single_targeted := card_ui.card.is_single_targeted()
	var first_target_is_enemy := card_ui.targets[0] is Enemy
	
	if single_targeted and not first_target_is_enemy:
		return

	card_ui.play()


func post_enter() -> void:
	transition_requested.emit(self, CardState.State.BASE)
