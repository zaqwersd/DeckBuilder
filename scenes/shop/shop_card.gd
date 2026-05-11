class_name ShopCard
extends VBoxContainer

const CARD_MENU_UI = preload("res://scenes/ui/card_menu_ui.tscn")
const SHOP_CARD_MENU_SCALE := 1
## 与 shop_card.tscn 根节点一致：售出后占位，避免同列其它格位移
const SLOT_SIZE := Vector2(120, 170)

@export var card: Card : set = set_card

@onready var card_container: Control = %CardContainer
@onready var price: HBoxContainer = %Price
@onready var price_label: Label = %PriceLabel
@onready var gold_cost := RNG.instance.randi_range(100, 300)

var current_card_ui: CardMenuUI
var _run_stats: RunStats
var _sold := false


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
	
	var new_card_menu_ui := CARD_MENU_UI.instantiate() as CardMenuUI
	card_container.add_child(new_card_menu_ui)
	new_card_menu_ui.card = card
	if not new_card_menu_ui.card_pick_pressed.is_connected(_on_card_pick_pressed):
		new_card_menu_ui.card_pick_pressed.connect(_on_card_pick_pressed)
	current_card_ui = new_card_menu_ui
	_apply_shop_card_menu_scale.call_deferred(new_card_menu_ui, 0)


func _apply_shop_card_menu_scale(ui: CardMenuUI, attempt: int = 0) -> void:
	if not is_instance_valid(ui) or ui.get_parent() != card_container:
		return
	if ui.size == Vector2.ZERO and attempt < 10:
		_apply_shop_card_menu_scale.call_deferred(ui, attempt + 1)
		return
	# 用固定槽位包住缩放后的卡面，避免布局仍按未缩放尺寸占位把遗物行挤出视口
	ui.pivot_offset = Vector2.ZERO
	ui.scale = Vector2.ONE * SHOP_CARD_MENU_SCALE
	var scaled := ui.size * SHOP_CARD_MENU_SCALE
	card_container.custom_minimum_size = scaled
	ui.position = Vector2.ZERO


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
