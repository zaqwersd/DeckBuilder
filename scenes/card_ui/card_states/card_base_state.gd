extends CardState


func _hand_interaction_enabled() -> bool:
	return not card_ui.disabled


func _hand_drag_start_enabled() -> bool:
	return _hand_interaction_enabled() and (card_ui.playable or card_ui.allows_hand_drag_preview())


func enter() -> void:
	if not card_ui.is_node_ready():
		await card_ui.ready

	if card_ui.tween and card_ui.tween.is_running():
		card_ui.tween.kill()

	card_ui.card_visuals.panel.set("theme_override_styles/panel", card_ui.card_visuals.main_panel_style_base)
	card_ui.z_index = 0
	card_ui.z_as_relative = true
	# 打出时 _play_resolved 在 await 前已挂到 ui_layer 并清空 hand_slot；或从手牌拖出打出时 hand_slot 仍在
	# 但 parent 已是 ui_layer。Released→BASE 若再 emit，Hand 会把牌 reparent 到 HBox 根上 → 满宽空槽。
	if not is_instance_valid(card_ui.hand_slot):
		var walk: Node = card_ui.get_parent()
		while is_instance_valid(walk):
			if walk.is_in_group("ui_layer"):
				return
			walk = walk.get_parent()
	if is_instance_valid(card_ui.hand_slot) and card_ui.get_parent() != card_ui.hand_slot and not card_ui.visible:
		var walk2: Node = card_ui.get_parent()
		while is_instance_valid(walk2):
			if walk2.is_in_group("ui_layer"):
				return
			walk2 = walk2.get_parent()
	card_ui.reparent_requested.emit(card_ui)


func on_gui_input(event: InputEvent) -> void:
	if not _hand_drag_start_enabled():
		return

	if card_ui.is_hand_pointer_over_this_card() and event.is_action_pressed("left_mouse"):
		card_ui.pivot_offset = card_ui.get_global_mouse_position() - card_ui.global_position
		transition_requested.emit(self, CardState.State.CLICKED)


## 手牌抬起 / z / 底板由 Hand 每帧 `sync_hand_hover_presentation` 驱动，此处不处理，避免与几何不同步。
func on_mouse_entered() -> void:
	pass


func on_mouse_exited() -> void:
	pass
