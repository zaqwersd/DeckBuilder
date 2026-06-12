extends CardState

const PLAY_AREA_SNAP_DURATION := 0.15

var _hand_drag_active := false
var _play_area_locked := false
var _aiming_active := false
## 拾起牌时的第一次左键松开：只结束「按住」，不打出也不回手牌。
var _ignore_pickup_left_release := true


func enter() -> void:
	card_ui.reset_hand_hover_lift_instant()
	if is_instance_valid(card_ui.hand_slot) and card_ui.hand_slot.get_parent() is Hand:
		card_ui.original_index = card_ui.hand_slot.get_index()

	_hand_drag_active = false
	_play_area_locked = false
	_aiming_active = false
	_ignore_pickup_left_release = true

	if card_ui.card.is_single_targeted():
		card_ui.drop_point_detector.monitoring = false
	else:
		card_ui.drop_point_detector.monitoring = true

	_begin_free_drag()
	_snap_card_to_mouse()
	if card_ui.card.is_single_targeted():
		_update_single_target_drag_position()
	set_process(true)


func exit() -> void:
	set_process(false)
	card_ui.set_process_input(false)
	card_ui.set_process_unhandled_input(false)
	if card_ui.card.is_single_targeted():
		if _aiming_active:
			Events.card_aim_ended.emit(card_ui)
	else:
		Events.card_drag_ended.emit(card_ui)
	_clear_drag_slot_meta()
	_reset_drag_flags()


func _process(_delta: float) -> void:
	if not is_instance_valid(card_ui) or not _hand_drag_active:
		return
	if card_ui.card.is_single_targeted():
		if not _play_area_locked:
			_update_single_target_drag_position()
	else:
		_snap_card_to_mouse()
	card_ui.z_index = CardUI.PICKED_CARD_Z_INDEX


func _reset_drag_flags() -> void:
	_hand_drag_active = false
	_play_area_locked = false
	_aiming_active = false
	_ignore_pickup_left_release = true


func _clear_drag_slot_meta() -> void:
	if is_instance_valid(card_ui.hand_slot) and card_ui.hand_slot.has_meta(Hand.META_SLOT_DRAG_TEMP_EMPTY):
		card_ui.hand_slot.remove_meta(Hand.META_SLOT_DRAG_TEMP_EMPTY)
		var h := card_ui.hand_slot.get_parent()
		if h is Hand:
			(h as Hand)._request_reflow_hand_bar()


func _begin_free_drag() -> void:
	if _hand_drag_active:
		return
	_hand_drag_active = true
	_prepare_drag_slot()
	var ui_layer := get_tree().get_first_node_in_group("ui_layer")
	if ui_layer:
		card_ui.reparent(ui_layer)
	card_ui.apply_picked_card_layer_order()
	card_ui.set_process_input(true)
	card_ui.set_process_unhandled_input(true)
	card_ui.card_visuals.panel.set("theme_override_styles/panel", card_ui.card_visuals.main_panel_style_drag)
	if not card_ui.card.is_single_targeted():
		Events.card_drag_started.emit(card_ui)


func _prepare_drag_slot() -> void:
	if not is_instance_valid(card_ui.hand_slot) or card_ui.get_parent() != card_ui.hand_slot:
		return
	card_ui.hand_slot.set_meta(Hand.META_SLOT_DRAG_TEMP_EMPTY, true)
	card_ui.hand_slot.custom_minimum_size = Vector2.ZERO
	var h := card_ui.hand_slot.get_parent()
	if h and h.has_method("_request_reflow_hand_bar"):
		h.call("_request_reflow_hand_bar")


func _snap_card_to_mouse() -> void:
	card_ui.global_position = card_ui.get_global_mouse_position() - card_ui.pivot_offset


func _update_single_target_drag_position() -> void:
	if not _hand_drag_active or _play_area_locked:
		return
	if card_ui.is_mouse_in_hand_zone():
		_snap_card_to_mouse()
	else:
		_commit_to_play_area()


func _commit_to_play_area() -> void:
	if _play_area_locked:
		return
	_play_area_locked = true
	if card_ui.tween and card_ui.tween.is_running():
		card_ui.tween.kill()
	card_ui.animate_to_position(card_ui.get_play_area_global_position(), PLAY_AREA_SNAP_DURATION)
	if not _aiming_active:
		_aiming_active = true
		Events.card_aim_started.emit(card_ui)


func _consume_pickup_left_release(event: InputEvent) -> bool:
	if not event.is_action_released("left_mouse"):
		return false
	if not _ignore_pickup_left_release:
		return false
	_ignore_pickup_left_release = false
	get_viewport().set_input_as_handled()
	return true


func on_gui_input(event: InputEvent) -> void:
	_handle_drag_event(event)


func on_input(event: InputEvent) -> void:
	_handle_drag_event(event)


func _handle_drag_event(event: InputEvent) -> void:
	if card_ui.card.is_single_targeted():
		_handle_single_target_drag_event(event)
	else:
		_handle_non_single_drag_event(event)


func _handle_non_single_drag_event(event: InputEvent) -> void:
	if event.is_action_released("right_mouse"):
		transition_requested.emit(self, CardState.State.BASE)
		return
	if _consume_pickup_left_release(event):
		return
	if event.is_action_pressed("left_mouse") and not card_ui.is_mouse_in_hand_zone():
		get_viewport().set_input_as_handled()
		transition_requested.emit(self, CardState.State.RELEASED)


func _handle_single_target_drag_event(event: InputEvent) -> void:
	if event.is_action_released("right_mouse"):
		transition_requested.emit(self, CardState.State.BASE)
		return
	if _consume_pickup_left_release(event):
		return
	if event.is_action_pressed("left_mouse") and _play_area_locked and not card_ui.targets.is_empty():
		get_viewport().set_input_as_handled()
		transition_requested.emit(self, CardState.State.RELEASED)
