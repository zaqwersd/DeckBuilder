class_name ShopCard
extends VBoxContainer

const SHOP_CARD_MENU_SCALE := 1
const PRICE_ROW_SHIFT_UP := 10.0

@export var card: Card : set = set_card

@onready var card_container: Control = %CardContainer
@onready var price_wrap: Control = %PriceWrap
@onready var price: HBoxContainer = %Price
@onready var price_label: Label = %PriceLabel
var gold_cost: int = -1

var current_card_ui: CardMenuUI
var _run_stats: RunStats
var _sold := false


func _ready() -> void:
	if gold_cost < 0:
		gold_cost = RNG.instance.randi_range(100, 300)
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", Shop.SHOP_ITEM_VBOX_SEP)


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
	call_deferred("_apply_listing_layout")


func _apply_listing_layout() -> void:
	if _sold or has_meta(Shop.SHOP_ITEM_LAYOUT_DONE_META):
		return
	var menu := current_card_ui
	if not is_instance_valid(menu) or menu.get_parent() != card_container:
		return
	if menu.size == Vector2.ZERO:
		call_deferred("_apply_listing_layout")
		return
	menu.pivot_offset = Vector2.ZERO
	menu.scale = Vector2.ONE * SHOP_CARD_MENU_SCALE
	var scaled := menu.size * SHOP_CARD_MENU_SCALE
	if card_container:
		card_container.clip_contents = false
		card_container.custom_minimum_size = scaled
		card_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	menu.position = Vector2.ZERO
	menu.refresh_listing_hover_pivot()
	var col_w := Shop.LISTING_CARD_VISUAL_SIZE.x
	var vbox_sep := float(get_theme_constant("separation", "VBoxContainer"))
	var price_band := price.get_combined_minimum_size().y if price else 0.0
	var wrap_h := maxf(0.0, price_band + vbox_sep - PRICE_ROW_SHIFT_UP)
	if price_wrap:
		price_wrap.custom_minimum_size = Vector2(col_w, wrap_h)
		price_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		price_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	custom_minimum_size = Vector2(col_w, scaled.y + wrap_h + vbox_sep)
	set_meta(Shop.SHOP_ITEM_LAYOUT_DONE_META, true)
	set_meta(Shop.SHOP_SLOT_BLOCK_SIZE_META, custom_minimum_size)


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
	if has_meta(Shop.SHOP_SLOT_BLOCK_SIZE_META):
		custom_minimum_size = get_meta(Shop.SHOP_SLOT_BLOCK_SIZE_META)
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
