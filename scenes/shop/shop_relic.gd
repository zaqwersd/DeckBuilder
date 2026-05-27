class_name ShopRelic
extends VBoxContainer

const RELIC_UI = preload("res://scenes/relic_handler/relic_ui.tscn")

@export var relic: Relic : set = set_relic

@onready var relic_container: CenterContainer = %RelicContainer
@onready var price: HBoxContainer = %Price
@onready var price_label: Label = %PriceLabel
var gold_cost: int = -1

var _run_stats: RunStats
var _sold := false


func _ready() -> void:
	if gold_cost < 0:
		gold_cost = RNG.instance.randi_range(100, 300)
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", Shop.SHOP_ITEM_VBOX_SEP)
	_lock_layout_size()


func configure_cost(cost: int) -> void:
	gold_cost = cost


func _lock_layout_size() -> void:
	if has_meta(Shop.SHOP_ITEM_LAYOUT_DONE_META):
		return
	var block := get_combined_minimum_size()
	if block.x < 1.0:
		block = Vector2(180.0, 167.0)
	set_meta(Shop.SHOP_ITEM_LAYOUT_DONE_META, true)
	set_meta(Shop.SHOP_SLOT_BLOCK_SIZE_META, block)
	custom_minimum_size = block


func update(run_stats: RunStats) -> void:
	if _sold:
		return
	_run_stats = run_stats
	if not price_label:
		return
	price_label.text = str(gold_cost)
	if run_stats.gold >= gold_cost:
		price_label.remove_theme_color_override("font_color")
	else:
		price_label.add_theme_color_override("font_color", Color.RED)


func set_relic(new_relic: Relic) -> void:
	if not is_node_ready():
		await ready
	relic = new_relic
	for relic_ui: RelicUI in relic_container.get_children():
		relic_ui.queue_free()
	var new_relic_ui := RELIC_UI.instantiate() as RelicUI
	relic_container.add_child(new_relic_ui)
	new_relic_ui.relic = relic
	if not new_relic_ui.relic_pressed.is_connected(_on_relic_pressed):
		new_relic_ui.relic_pressed.connect(_on_relic_pressed)
	call_deferred("_lock_layout_size")


func _on_relic_pressed(_r: Relic) -> void:
	if _sold or not _run_stats or _run_stats.gold < gold_cost:
		return
	Events.shop_relic_bought.emit(relic, gold_cost)
	mark_as_sold()


func is_sold() -> bool:
	return _sold


func mark_as_sold() -> void:
	_sold = true
	if has_meta(Shop.SHOP_SLOT_BLOCK_SIZE_META):
		custom_minimum_size = get_meta(Shop.SHOP_SLOT_BLOCK_SIZE_META)
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
