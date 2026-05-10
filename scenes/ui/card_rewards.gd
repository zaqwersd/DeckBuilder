class_name CardRewards
extends ColorRect

signal card_reward_selected(card: Card)

const CARD_MENU_UI = preload("res://scenes/ui/card_menu_ui.tscn")

@export var rewards: Array[Card] : set = set_rewards

@onready var cards: HBoxContainer = %Cards
@onready var skip_card_reward: Button = %SkipCardReward
@onready var take_button: Button = %TakeButton

var selected_card: Card


func _ready() -> void:
	_clear_rewards()

	take_button.pressed.connect(
		func():
			if selected_card == null:
				return
			card_reward_selected.emit(selected_card)
			queue_free()
	)

	skip_card_reward.pressed.connect(
		func():
			card_reward_selected.emit(null)
			queue_free()
	)


func _clear_rewards() -> void:
	for card: Node in cards.get_children():
		card.queue_free()

	selected_card = null
	take_button.disabled = true


func _on_card_pick_pressed(card: Card) -> void:
	selected_card = card
	take_button.disabled = false


func set_rewards(new_cards: Array[Card]) -> void:
	rewards = new_cards

	if not is_node_ready():
		await ready

	_clear_rewards()
	for card: Card in rewards:
		var new_card := CARD_MENU_UI.instantiate() as CardMenuUI
		cards.add_child(new_card)
		new_card.card = card
		new_card.card_pick_pressed.connect(_on_card_pick_pressed)
