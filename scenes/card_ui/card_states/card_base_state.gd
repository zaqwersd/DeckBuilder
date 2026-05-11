extends CardState

## 高于手牌内其它卡（默认 0），保证重叠时鼠标命中与绘制顺序一致
const HAND_HOVER_Z := 10

var mouse_over_card := false


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
	card_ui.reparent_requested.emit(card_ui)


func on_gui_input(event: InputEvent) -> void:
	if not _hand_drag_start_enabled():
		return

	if mouse_over_card and event.is_action_pressed("left_mouse"):
		card_ui.pivot_offset = card_ui.get_global_mouse_position() - card_ui.global_position
		transition_requested.emit(self, CardState.State.CLICKED)


func on_mouse_entered() -> void:
	mouse_over_card = true
	
	if not _hand_interaction_enabled():
		return

	card_ui.z_index = HAND_HOVER_Z
	card_ui.card_visuals.panel.set("theme_override_styles/panel", card_ui.card_visuals.main_panel_style_hover)
	card_ui.refresh_combat_description()
	card_ui.tween_hand_hover_lift_y(-CardUI.HAND_HOVER_LIFT_PX)


func on_mouse_exited() -> void:
	mouse_over_card = false
	
	if not _hand_interaction_enabled():
		return

	card_ui.z_index = 0
	card_ui.card_visuals.panel.set("theme_override_styles/panel", card_ui.card_visuals.main_panel_style_base)
	card_ui.tween_hand_hover_lift_y(0.0)
