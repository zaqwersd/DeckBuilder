class_name ShopRelic
extends VBoxContainer

@export var relic: Relic : set = set_relic

@onready var relic_icon_anchor: CenterContainer = %RelicIconAnchor
@onready var relic_icon: TextureRect = %RelicIcon
@onready var price_label: Label = %PriceLabel
var gold_cost: int = -1

var _run_stats: RunStats
var _sold := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if relic_icon_anchor:
		relic_icon_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if relic_icon:
		relic_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)
	if gold_cost < 0:
		gold_cost = RNG.instance.randi_range(100, 300)
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", Shop.SHOP_ITEM_VBOX_SEP)
	_lock_layout_size()
	if relic != null:
		_refresh_relic_icon()


func is_pointer_over() -> bool:
	if _sold or not is_instance_valid(self):
		return false
	var viewport := get_viewport()
	if viewport == null:
		return false
	return CombatPointer.control_has_screen_point(self, CombatPointer.screen_mouse(viewport))


func get_tooltip_anchor() -> Control:
	return self


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
	modulate = Color.WHITE
	_refresh_interactable()


func set_relic(new_relic: Relic) -> void:
	if not is_node_ready():
		await ready
	relic = new_relic
	_refresh_relic_icon()
	call_deferred("_lock_layout_size")


func _refresh_relic_icon() -> void:
	if relic == null or not is_instance_valid(relic_icon):
		return
	if relic.icon:
		relic_icon.texture = RelicIconUtil.get_colored_icon(relic.icon as Texture2D, relic.rarity)


func _can_purchase() -> bool:
	return _run_stats != null and _run_stats.gold >= gold_cost


func _refresh_interactable() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if _sold else Control.MOUSE_FILTER_STOP


func _on_gui_input(event: InputEvent) -> void:
	if _sold or not _run_stats:
		return
	if not event.is_action_pressed("left_mouse"):
		return
	if not _can_purchase():
		Shaker.shake_control(self, 5.0, 0.12)
		return
	TooltipHoverUtil.hide_immediate(get_tree())
	Events.shop_relic_bought.emit(relic, gold_cost)
	mark_as_sold()


func is_sold() -> bool:
	return _sold


func mark_as_sold() -> void:
	TooltipHoverUtil.hide_immediate(get_tree())
	_sold = true
	if has_meta(Shop.SHOP_SLOT_BLOCK_SIZE_META):
		custom_minimum_size = get_meta(Shop.SHOP_SLOT_BLOCK_SIZE_META)
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
