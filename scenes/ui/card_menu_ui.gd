class_name CardMenuUI
extends CenterContainer

## 用于奖励选牌等：在卡面上点击时发出（不再弹出卡牌 tooltip）
signal card_pick_pressed(card: Card)

@export var card: Card : set = set_card

@onready var visuals: CardVisuals = $Visuals


func set_modifier_preview(player_modifiers: ModifierHandler, enemy_modifiers: ModifierHandler) -> void:
	if is_node_ready() and visuals:
		visuals.apply_modifier_context(player_modifiers, enemy_modifiers)


func _on_visuals_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_mouse") and card:
		card_pick_pressed.emit(card)


func _on_visuals_mouse_entered() -> void:
	visuals.panel.set("theme_override_styles/panel", visuals.main_panel_style_hover)


func _on_visuals_mouse_exited() -> void:
	visuals.panel.set("theme_override_styles/panel", visuals.main_panel_style_base)


func set_card(value: Card) -> void:
	if not is_node_ready():
		await ready

	card = value
	visuals.card = card
