extends CardState


func enter() -> void:
	card_ui.drop_point_detector.monitoring = true
	var p := card_ui.get_parent()
	if p and p.get_parent() is Hand:
		card_ui.original_index = p.get_index()
	else:
		card_ui.original_index = card_ui.get_index()


func on_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		transition_requested.emit(self, CardState.State.DRAGGING)
