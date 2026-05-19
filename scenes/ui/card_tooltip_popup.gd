class_name CardTooltipPopup
extends Control

const CARD_MENU_UI_SCENE := preload("res://scenes/ui/card_menu_ui.tscn")

@export var background_color: Color = Color("000000b0")

@onready var background: ColorRect = $Background
@onready var tooltip_card: CenterContainer = %TooltipCard
@onready var card_description: RichTextLabel = %CardDescription


func _ready() -> void:
	for card: CardMenuUI in tooltip_card.get_children():
		card.queue_free()
		
	background.color = background_color
	card_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func show_tooltip(card: Card) -> void:
	var new_card := CARD_MENU_UI_SCENE.instantiate() as CardMenuUI
	tooltip_card.add_child(new_card)
	new_card.card = card
	new_card.card_pick_pressed.connect(hide_tooltip.unbind(1))
	card_description.text = CardVisualsBase.format_description_bbcode_for_wrap(
		card.get_visual_description_bbcode()
	)
	show()


func hide_tooltip() -> void:
	if not visible:
		return

	for card: CardMenuUI in tooltip_card.get_children():
		card.queue_free()
	
	hide()


func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_mouse"):
		hide_tooltip()
