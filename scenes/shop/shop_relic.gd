class_name ShopRelic
extends VBoxContainer

const RELIC_UI = preload("res://scenes/relic_handler/relic_ui.tscn")
## 与 shop_relic.tscn 根节点一致：售出后占位
const SLOT_SIZE := Vector2(180, 135)

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


func configure_cost(cost: int) -> void:
	gold_cost = cost


func update(run_stats: RunStats) -> void:
	if _sold:
		return
	_run_stats = run_stats
	if not relic_container or not price or not price_label:
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


func _on_relic_pressed(_r: Relic) -> void:
	if _sold or not _run_stats or _run_stats.gold < gold_cost:
		return
	Events.shop_relic_bought.emit(relic, gold_cost)
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
