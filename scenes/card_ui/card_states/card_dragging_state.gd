extends CardState

const PLAY_AREA_SNAP_DURATION := 0.15

var _hand_drag_active := false
var _play_area_locked := false
var _aiming_active := false
## 拾起牌时的第一次左键松开：只结束「按住」，不打出也不回手牌。
var _ignore_pickup_left_release := true
## 非指向牌：在手牌区内松手后跟随鼠标，任意处再点左键打出。
var _click_follow_mode := false
## 按住拾起期间曾拖出手牌区（用于区外松手打出）。
var _dragged_outside_during_pickup := false


func enter() -> void:
	card_ui.reset_hand_hover_lift_instant()
	if is_instance_valid(card_ui.hand_slot) and card_ui.hand_slot.get_parent() is Hand:
		card_ui.original_index = card_ui.hand_slot.get_index()

	_hand_drag_active = false
	_play_area_locked = false
	_aiming_active = false
	_ignore_pickup_left_release = true
	_click_follow_mode = false
	_dragged_outside_during_pickup = false

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
	if card_ui.card.is_single_targeted() and _aiming_active:
		Events.card_aim_ended.emit(card_ui)
	Events.card_drag_ended.emit(card_ui)
	_clear_drag_slot_meta()
	_reset_drag_flags()


func _process(_delta: float) -> void:
	if not is_instance_valid(card_ui) or not _hand_drag_active:
		return
	if Input.is_action_just_pressed("right_mouse"):
		_cancel_drag_to_hand()
		return
	if card_ui.card.is_single_targeted():
		if not _play_area_locked:
			_update_single_target_drag_position()
			if _ignore_pickup_left_release and _is_outside_hand_for_drag_play():
				_dragged_outside_during_pickup = true
	else:
		_snap_card_to_mouse()
		if _ignore_pickup_left_release and _is_outside_hand_for_drag_play():
			_dragged_outside_during_pickup = true
	card_ui.z_index = CardUI.PICKED_CARD_Z_INDEX


func _reset_drag_flags() -> void:
	_hand_drag_active = false
	_play_area_locked = false
	_aiming_active = false
	_ignore_pickup_left_release = true
	_click_follow_mode = false
	_dragged_outside_during_pickup = false


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


func _resolve_hand() -> Hand:
	return card_ui._resolve_combat_hand()


func _is_global_point_in_hand_zone(global_point: Vector2) -> bool:
	var hand := _resolve_hand()
	if hand == null:
		return false
	return hand.is_mouse_in_play_drag_hand_zone(global_point)


## 鼠标或牌心离开手牌区即视为拖出（pivot 会导致牌已上移但鼠标仍在带内）。
## 判定「是否拖出手牌区」：鼠标仍在该牌命中四边形内则视为未拖出，避免描述区/右侧溢出段误判。
func _is_outside_hand_for_drag_play() -> bool:
	if card_ui.is_global_point_in_hand_pick(card_ui.get_global_mouse_position()):
		return false
	return not card_ui.is_mouse_in_hand_zone()


func _should_play_on_pickup_release() -> bool:
	var card := card_ui.card
	if card != null and card.requires_drag_outside_hand_before_play():
		return _dragged_outside_during_pickup
	return _dragged_outside_during_pickup or _is_outside_hand_for_drag_play()


func _cancel_drag_to_hand() -> void:
	card_ui.targets.clear()
	card_ui.refresh_combat_description()
	transition_requested.emit(self, CardState.State.BASE)


func _sync_target_from_mouse() -> void:
	var tree := card_ui.get_tree()
	if tree == null:
		return
	var best := EnemyTargeting.pick_enemy_under_mouse(card_ui.get_global_mouse_position(), tree)
	card_ui.targets.clear()
	if best != null:
		card_ui.targets.append(best)
	card_ui.refresh_combat_description()


func _handle_single_target_left_release() -> void:
	_sync_target_from_mouse()
	if not card_ui.targets.is_empty():
		transition_requested.emit(self, CardState.State.RELEASED)
		return
	if not _play_area_locked and (_dragged_outside_during_pickup or _is_outside_hand_for_drag_play()):
		_commit_to_play_area()


func _try_cancel_with_right_mouse(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and (mb.pressed or not mb.pressed):
			get_viewport().set_input_as_handled()
			_cancel_drag_to_hand()
			return true
	if event.is_action_pressed("right_mouse") or event.is_action_released("right_mouse"):
		get_viewport().set_input_as_handled()
		_cancel_drag_to_hand()
		return true
	return false


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
	if _try_cancel_with_right_mouse(event):
		return
	if event.is_action_released("left_mouse") and _ignore_pickup_left_release:
		_ignore_pickup_left_release = false
		get_viewport().set_input_as_handled()
		if _should_play_on_pickup_release():
			transition_requested.emit(self, CardState.State.RELEASED)
		else:
			_click_follow_mode = true
		return
	if _click_follow_mode and event.is_action_pressed("left_mouse"):
		get_viewport().set_input_as_handled()
		transition_requested.emit(self, CardState.State.RELEASED)


func _handle_single_target_drag_event(event: InputEvent) -> void:
	if _try_cancel_with_right_mouse(event):
		return
	if event.is_action_released("left_mouse"):
		get_viewport().set_input_as_handled()
		if _ignore_pickup_left_release:
			_ignore_pickup_left_release = false
		_handle_single_target_left_release()
		return
	if event.is_action_pressed("left_mouse") and _play_area_locked and not card_ui.targets.is_empty():
		get_viewport().set_input_as_handled()
		transition_requested.emit(self, CardState.State.RELEASED)
