class_name ShopCard
extends VBoxContainer

const SHOP_CARD_MENU_SCALE := 1
## 与 shop_card.tscn 根节点一致：售出后占位，避免同列其它格位移
const SLOT_SIZE := Vector2(120, 170)

@export var card: Card : set = set_card

@onready var card_container: Control = %CardContainer
@onready var price: HBoxContainer = %Price
@onready var price_label: Label = %PriceLabel
var gold_cost: int = -1

var current_card_ui: CardMenuUI
var _run_stats: RunStats
var _sold := false


func _ready() -> void:
	if gold_cost < 0:
		gold_cost = RNG.instance.randi_range(100, 300)


func configure_cost(cost: int) -> void:
	gold_cost = cost


func is_sold() -> bool:
	return _sold


func update(run_stats: RunStats) -> void:
	if _sold:
		return
	_run_stats = run_stats
	if not card_container or not price or not price_label:
		return

	price_label.text = str(gold_cost)
	
	if run_stats.gold >= gold_cost:
		price_label.remove_theme_color_override("font_color")
	else:
		price_label.add_theme_color_override("font_color", Color.RED)


func set_card(new_card: Card) -> void:
	if not is_node_ready():
		await ready

	card = new_card
	
	for card_menu_ui: CardMenuUI in card_container.get_children():
		card_menu_ui.queue_free()
	
	var new_card_menu_ui := CardGridListing.make_listing_card_menu()
	card_container.add_child(new_card_menu_ui)
	new_card_menu_ui.card = card
	if not new_card_menu_ui.card_pick_pressed.is_connected(_on_card_pick_pressed):
		new_card_menu_ui.card_pick_pressed.connect(_on_card_pick_pressed)
	current_card_ui = new_card_menu_ui
	# 勿通过 call_deferred 传 Node：消息队列里会出现 Object→Object 转换失败
	call_deferred("_deferred_apply_shop_card_menu_scale")


func _deferred_apply_shop_card_menu_scale() -> void:
	_apply_shop_card_menu_scale(0)


func _deferred_retry_shop_card_menu_scale(attempt: int) -> void:
	_apply_shop_card_menu_scale(attempt)


func _apply_shop_card_menu_scale(attempt: int) -> void:
	var menu := current_card_ui
	if not is_instance_valid(menu) or not menu is CardMenuUI or menu.get_parent() != card_container:
		return
	if menu.size == Vector2.ZERO and attempt < 10:
		call_deferred("_deferred_retry_shop_card_menu_scale", attempt + 1)
		return
	# 用固定槽位包住缩放后的卡面，避免布局仍按未缩放尺寸占位把遗物行挤出视口
	menu.pivot_offset = Vector2.ZERO
	menu.scale = Vector2.ONE * SHOP_CARD_MENU_SCALE
	var scaled := menu.size * SHOP_CARD_MENU_SCALE
	card_container.custom_minimum_size = scaled
	menu.position = Vector2.ZERO
	menu.refresh_listing_hover_pivot()


func set_modifier_context(handler: ModifierHandler) -> void:
	if current_card_ui:
		current_card_ui.set_modifier_preview(handler, null)


func _on_card_pick_pressed(_picked: Card) -> void:
	if _sold or not _run_stats or _run_stats.gold < gold_cost:
		return
	Events.shop_card_bought.emit(card, gold_cost, card_container)
	mark_as_sold()


func mark_as_sold() -> void:
	_sold = true
	var keep := size
	var w := maxf(keep.x, SLOT_SIZE.x) if keep.x > 1.0 else SLOT_SIZE.x
	var h := maxf(keep.y, SLOT_SIZE.y) if keep.y > 1.0 else SLOT_SIZE.y
	for c: Node in get_children():
		c.queue_free()
	var hold := Control.new()
	hold.custom_minimum_size = Vector2(w, h)
	hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hold)
