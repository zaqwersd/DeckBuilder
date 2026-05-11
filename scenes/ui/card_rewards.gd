class_name CardRewards
extends ColorRect

## picked_menu 为选中的 CardMenuUI（会从本面板摘下再飞入牌库）；跳过奖励时发 null
signal card_reward_selected(picked_menu: Variant, from_global: Vector2)

const CARD_MENU_UI = preload("res://scenes/ui/card_menu_ui.tscn")

@export var rewards: Array[Card] : set = set_rewards

@onready var cards: HBoxContainer = %Cards
@onready var skip_card_reward: Button = %SkipCardReward


func _ready() -> void:
	_clear_rewards()

	skip_card_reward.pressed.connect(
		func():
			card_reward_selected.emit(null, Vector2.ZERO)
			queue_free()
	)


func _clear_rewards() -> void:
	for card: Node in cards.get_children():
		card.queue_free()


func _on_reward_tile_pressed(menu: CardMenuUI, _card: Card) -> void:
	var from := menu.get_global_rect().get_center()
	var p := menu.get_parent()
	if p:
		p.remove_child(menu)
	card_reward_selected.emit(menu, from)
	queue_free()


func set_rewards(new_cards: Array[Card]) -> void:
	rewards = new_cards

	if not is_node_ready():
		await ready

	_clear_rewards()
	for card: Card in rewards:
		var new_card := CARD_MENU_UI.instantiate() as CardMenuUI
		cards.add_child(new_card)
		new_card.card = card
		new_card.card_pick_pressed.connect(func(c: Card) -> void: _on_reward_tile_pressed(new_card, c))
