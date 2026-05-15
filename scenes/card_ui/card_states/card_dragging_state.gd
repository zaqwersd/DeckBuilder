extends CardState

const DRAG_MINIMUM_THRESHOLD := 0.05

var minimum_drag_time_elapsed := false


func enter() -> void:
	card_ui.reset_hand_hover_lift_instant()
	if is_instance_valid(card_ui.hand_slot) and card_ui.get_parent() == card_ui.hand_slot:
		card_ui.hand_slot.set_meta(Hand.META_SLOT_DRAG_TEMP_EMPTY, true)
		# 槽仍占位会拖慢整手居中：拖出时宽度压为 0，松手回槽再由 Hand 恢复 minimum_size
		card_ui.hand_slot.custom_minimum_size = Vector2.ZERO
		var h := card_ui.hand_slot.get_parent()
		if h and h.has_method("_request_reflow_hand_bar"):
			h.call("_request_reflow_hand_bar")
	var ui_layer := get_tree().get_first_node_in_group("ui_layer")
	if ui_layer:
		card_ui.reparent(ui_layer)
		card_ui.move_to_front()
	card_ui.z_index = 128
	card_ui.z_as_relative = false

	card_ui.card_visuals.panel.set("theme_override_styles/panel", card_ui.card_visuals.main_panel_style_drag)
	Events.card_drag_started.emit(card_ui)
	
	minimum_drag_time_elapsed = false
	var threshold_timer := get_tree().create_timer(DRAG_MINIMUM_THRESHOLD, false)
	threshold_timer.timeout.connect(_on_drag_threshold_elapsed, CONNECT_ONE_SHOT)


func exit() -> void:
	Events.card_drag_ended.emit(card_ui)


func _on_drag_threshold_elapsed() -> void:
	if not is_inside_tree() or not is_instance_valid(card_ui):
		return
	minimum_drag_time_elapsed = true


func on_input(event: InputEvent) -> void:
	var single_targeted := card_ui.card.is_single_targeted()
	var mouse_motion := event is InputEventMouseMotion
	var cancel = event.is_action_pressed("right_mouse")
	var confirm = event.is_action_released("left_mouse") or event.is_action_pressed("left_mouse")

	if single_targeted and mouse_motion and card_ui.targets.size() > 0:
		transition_requested.emit(self, CardState.State.AIMING)
		return
	
	if mouse_motion:
		card_ui.global_position = card_ui.get_global_mouse_position() - card_ui.pivot_offset

	if cancel:
		transition_requested.emit(self, CardState.State.BASE)
	elif minimum_drag_time_elapsed and confirm:
		get_viewport().set_input_as_handled()
		transition_requested.emit(self, CardState.State.RELEASED)
