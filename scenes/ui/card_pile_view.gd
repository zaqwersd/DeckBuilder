class_name CardPileView
extends Control

const CARD_MENU_UI_SCENE := preload("res://scenes/ui/card_menu_ui.tscn")
@export var card_pile: CardPile
## 战斗中略小于 1；跑图牌库界面可保持 1。与 CardMenuUI 设计尺寸配套的中心缩放。
@export_range(0.65, 1.0, 0.01) var display_scale: float = 1.0

@onready var title: Label = %Title
@onready var cards: GridContainer = %Cards
@onready var back_button: Button = %BackButton


func _ready() -> void:
	back_button.pressed.connect(hide)

	for card: Node in cards.get_children():
		card.queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		hide()


func show_current_view(new_title: String, randomized: bool = false) -> void:
	for card: Node in cards.get_children():
		card.queue_free()

	title.text = new_title
	_update_view.call_deferred(randomized)


func _update_view(randomized: bool) -> void:
	if not card_pile:
		return

	var all_cards := card_pile.cards.duplicate()
	if randomized:
		all_cards.shuffle()

	for card: Card in all_cards:
		var new_card := CARD_MENU_UI_SCENE.instantiate() as CardMenuUI
		cards.add_child(new_card)
		new_card.card = card
		_apply_pile_card_transform(new_card)

	if is_equal_approx(display_scale, 1.0):
		cards.remove_theme_constant_override("v_separation")
	else:
		cards.add_theme_constant_override("v_separation", int(round(36.0 * display_scale)))

	show()


func _apply_pile_card_transform(menu: CardMenuUI) -> void:
	menu.scale = Vector2.ONE
	menu.pivot_offset = Vector2.ZERO
	if not is_equal_approx(display_scale, 1.0):
		menu.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
