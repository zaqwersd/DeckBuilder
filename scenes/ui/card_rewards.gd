class_name CardRewards
extends CanvasLayer

const CARD_MENU_UI_SCENE := preload("res://scenes/ui/card_menu_ui.tscn")

## picked_menu 为选中的 CardMenuUI（会从本面板摘下再飞入牌库）；跳过奖励时发 null
signal card_reward_selected(picked_menu: Variant, from_global: Vector2)

var rewards: Array[Card] : set = set_rewards

@onready var content: Control = %Content
@onready var cards: GridContainer = %Cards
@onready var skip_card_reward: Button = %SkipCardReward


func _ready() -> void:
	_clear_rewards()

	skip_card_reward.pressed.connect(
		func():
			card_reward_selected.emit(null, Vector2.ZERO)
			queue_free()
	)


func _enter_tree() -> void:
	Events.begin_pointer_exclusive_ui(self)


func _exit_tree() -> void:
	Events.end_pointer_exclusive_ui(self)


func _clear_rewards() -> void:
	Events.card_keyword_tooltip_hide.emit()
	for card: Node in cards.get_children():
		card.queue_free()


static func make_listing_card_menu() -> CardMenuUI:
	var menu := CARD_MENU_UI_SCENE.instantiate() as CardMenuUI
	menu.use_listing_hover_zoom = true
	menu.mouse_filter = Control.MOUSE_FILTER_STOP
	menu.call_deferred("refresh_listing_hover_pivot")
	return menu


func create_listing_card_menu() -> CardMenuUI:
	return make_listing_card_menu()


func _on_reward_card_pick_pressed(menu: Variant, _card: Variant) -> void:
	if not is_inside_tree():
		return
	## bind 把 menu 插在第1位，信号原参数 card 在第2位
	var m := menu as CardMenuUI
	var c := _card as Card
	if m == null:
		m = _card as CardMenuUI
		c = menu as Card
	if m == null:
		return
	_on_reward_tile_pressed(m, c)


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
		var new_card := create_listing_card_menu()
		cards.add_child(new_card)
		new_card.card = card
		new_card.card_pick_pressed.connect(_on_reward_card_pick_pressed.bind(new_card))
