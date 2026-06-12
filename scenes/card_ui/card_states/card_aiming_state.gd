extends CardState


func _snapback_y_threshold() -> float:
	# Original tutorial used 138px at 144p viewport (~95.8% from top). Scale with viewport height.
	return card_ui.get_viewport_rect().size.y * (138.0 / 144.0)


func enter() -> void:
	card_ui.apply_picked_card_layer_order()
	card_ui.animate_to_position(card_ui.get_play_area_global_position(), 0.2)
	card_ui.drop_point_detector.monitoring = false
	Events.card_aim_started.emit(card_ui)


func exit() -> void:
	Events.card_aim_ended.emit(card_ui)


func on_input(event: InputEvent) -> void:	
	var mouse_motion := event is InputEventMouseMotion
	var mouse_at_bottom := card_ui.get_global_mouse_position().y > _snapback_y_threshold()
	
	if (mouse_motion and mouse_at_bottom) or event.is_action_pressed("right_mouse"):
		card_ui.targets.clear()
		transition_requested.emit(self, CardState.State.BASE)
	elif event.is_action_released("left_mouse"):
		if card_ui.card.is_single_targeted() and card_ui.targets.is_empty():
			return
		get_viewport().set_input_as_handled()
		transition_requested.emit(self, CardState.State.RELEASED)
