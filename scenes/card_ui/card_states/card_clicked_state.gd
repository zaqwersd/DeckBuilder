extends CardState


func enter() -> void:
	transition_requested.emit(self, CardState.State.DRAGGING)
