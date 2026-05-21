class_name CardPickOverlay
extends CanvasLayer

## 战后奖励、武术大师等「从若干候选中选一张加入牌库」的共用模态层。
const SCENE := preload("res://scenes/ui/card_pick_overlay.tscn")
const PICK_TITLE_TEXT := "选择一张牌。"

signal card_pick_selected(picked_menu: Variant, from_global: Vector2)
signal card_pick_skipped
signal card_pick_back

var rewards: Array[Card] : set = set_rewards

@onready var content: CardPreviewListHover = %Content
@onready var pick_title: Label = %PickTitle
@onready var cards: GridContainer = %Cards
@onready var back_button: Button = %BackCardReward
@onready var skip_button: Button = %SkipCardReward


static func present(cards: Array[Card]) -> CardPickOverlay:
	var overlay := SCENE.instantiate() as CardPickOverlay
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		push_error("CardPickOverlay.present: SceneTree root unavailable")
		return overlay
	tree.root.add_child(overlay)
	overlay.rewards = cards
	overlay.show()
	return overlay


func _ready() -> void:
	pick_title.text = PICK_TITLE_TEXT
	_clear_rewards()
	back_button.pressed.connect(_on_back_pressed)
	skip_button.pressed.connect(_on_skip_pressed)


func _enter_tree() -> void:
	Events.begin_pointer_exclusive_ui(self)


func _exit_tree() -> void:
	Events.end_pointer_exclusive_ui(self)


func _on_back_pressed() -> void:
	card_pick_back.emit()
	queue_free()


func _on_skip_pressed() -> void:
	card_pick_skipped.emit()
	queue_free()


func _clear_rewards() -> void:
	if is_instance_valid(content):
		content.reset_listing_keyword_tooltip_state()
	for card: Node in cards.get_children():
		card.free()


func _on_reward_card_pick_pressed(menu: Variant, _card: Variant) -> void:
	if not is_inside_tree():
		return
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
	card_pick_selected.emit(menu, from)
	queue_free()


func set_rewards(new_cards: Array[Card]) -> void:
	rewards = new_cards

	if not is_node_ready():
		await ready

	_clear_rewards()
	cards.columns = CardGridListing.LISTING_GRID_COLUMNS
	for card: Card in rewards:
		var new_card := CardGridListing.make_listing_card_menu()
		cards.add_child(new_card)
		new_card.card = card
		new_card.card_pick_pressed.connect(_on_reward_card_pick_pressed.bind(new_card))
