class_name ShopPotion
extends VBoxContainer

const SHOP_POTION_TOOLTIP_ICON_GAP := 0.0
const TOOLTIP_ICON_GAP_META := &"tooltip_icon_gap"

@export var potion: Potion : set = set_potion

@onready var icon_anchor: CenterContainer = %IconAnchor
@onready var icon_rect: TextureRect = %Icon
@onready var price_label: Label = %PriceLabel

var gold_cost: int = -1
var _run_stats: RunStats
var _sold := false
var _inventory_full := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)
	if icon_anchor:
		icon_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon_rect:
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if gold_cost < 0:
		gold_cost = maxi(1, int(round(RNG.instance.randi_range(80, 120) * Shop.SHOP_POTION_PRICE_FACTOR)))
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", Shop.SHOP_ITEM_VBOX_SEP)
	_lock_layout_size()


func is_pointer_over() -> bool:
	if _sold or not is_instance_valid(self):
		return false
	var viewport := get_viewport()
	if viewport == null:
		return false
	return CombatPointer.control_has_screen_point(self, CombatPointer.screen_mouse(viewport))


func get_tooltip_anchor() -> Control:
	return icon_anchor if icon_anchor else self


func configure_cost(cost: int) -> void:
	gold_cost = cost


func _lock_layout_size() -> void:
	if has_meta(Shop.SHOP_ITEM_LAYOUT_DONE_META):
		return
	var block := get_combined_minimum_size()
	if block.x < 1.0:
		block = Vector2(77.0, 88.0)
	set_meta(Shop.SHOP_ITEM_LAYOUT_DONE_META, true)
	set_meta(Shop.SHOP_SLOT_BLOCK_SIZE_META, block)
	custom_minimum_size = block


func set_inventory_full(full: bool) -> void:
	_inventory_full = full
	if is_node_ready():
		_refresh_interactable()


func is_sold() -> bool:
	return _sold


func mark_as_sold() -> void:
	TooltipHoverUtil.hide_immediate(get_tree())
	_sold = true
	if has_meta(Shop.SHOP_SLOT_BLOCK_SIZE_META):
		custom_minimum_size = get_meta(Shop.SHOP_SLOT_BLOCK_SIZE_META)
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


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


func _can_purchase() -> bool:
	return _run_stats != null and not _inventory_full and _run_stats.gold >= gold_cost


func _play_denied_shake() -> void:
	Shaker.shake_control(self, 5.0, 0.12)


func _refresh_interactable() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if _sold else Control.MOUSE_FILTER_STOP


func set_potion(new_potion: Potion) -> void:
	if not is_node_ready():
		await ready
	potion = new_potion
	if icon_rect and potion != null and potion.icon:
		icon_rect.texture = potion.icon
	call_deferred("_lock_layout_size")


func _on_gui_input(event: InputEvent) -> void:
	if _sold or not _run_stats:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _can_purchase():
			_play_denied_shake()
			return
		TooltipHoverUtil.hide_immediate(get_tree())
		Events.shop_potion_bought.emit(potion, gold_cost)
		mark_as_sold()
