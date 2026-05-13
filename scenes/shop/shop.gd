class_name Shop
extends Control

const SHOP_CARD = preload("res://scenes/shop/shop_card.tscn")
const SHOP_RELIC = preload("res://scenes/shop/shop_relic.tscn")

@export var shop_relics: Array[Relic]
@export var char_stats: CharacterStats
@export var run_stats: RunStats
@export var relic_handler: RelicHandler

@onready var shop_columns: HBoxContainer = %ShopColumns
@onready var shop_keeper_animation: AnimationPlayer = %ShopkeeperAnimation
@onready var blink_timer: Timer = %BlinkTimer
@onready var modifier_handler: ModifierHandler = $ModifierHandler

var _kw_tip_menu: CardMenuUI = null
var _kw_tip_ids: PackedStringArray = PackedStringArray()


func _ready() -> void:
	set_process(true)
	for col: Node in shop_columns.get_children():
		col.queue_free()

	Events.shop_card_bought.connect(_on_shop_card_bought)
	Events.shop_relic_bought.connect(_on_shop_relic_bought)

	_blink_timer_setup()
	blink_timer.timeout.connect(_on_blink_timer_timeout)


func _exit_tree() -> void:
	if _kw_tip_menu != null:
		_kw_tip_menu = null
		_kw_tip_ids = PackedStringArray()
		Events.card_keyword_tooltip_hide.emit()


func _process(_delta: float) -> void:
	if _kw_tip_menu != null and not is_instance_valid(_kw_tip_menu):
		_kw_tip_menu = null
		_kw_tip_ids = PackedStringArray()
		Events.card_keyword_tooltip_hide.emit()
	var winner: CardMenuUI = null
	var tip_ids: PackedStringArray = PackedStringArray()
	var best_d2 := INF
	var mp := get_global_mouse_position()
	for col: Node in shop_columns.get_children():
		for ch: Node in col.get_children():
			if not ch is ShopCard:
				continue
			var sc := ch as ShopCard
			if sc.is_sold():
				continue
			var m := sc.current_card_ui
			if m == null or not is_instance_valid(m):
				continue
			if not m.is_listing_pointer_over_visuals():
				continue
			if not is_instance_valid(m.visuals):
				continue
			var ids := m.visuals.get_keyword_tooltip_ids()
			if ids.is_empty():
				continue
			var d2 := m.visuals.get_global_rect().get_center().distance_squared_to(mp)
			if d2 < best_d2 - 0.01:
				winner = m
				tip_ids = ids
				best_d2 = d2
	_sync_shop_listing_keyword_tooltip(winner, tip_ids)


func _kw_tip_ids_equal(a: PackedStringArray, b: PackedStringArray) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if a[i] != b[i]:
			return false
	return true


func _sync_shop_listing_keyword_tooltip(winner: CardMenuUI, ids: PackedStringArray) -> void:
	if winner == _kw_tip_menu and _kw_tip_ids_equal(ids, _kw_tip_ids):
		return
	_kw_tip_menu = winner
	_kw_tip_ids = ids.duplicate() if winner != null else PackedStringArray()
	if winner == null:
		Events.card_keyword_tooltip_hide.emit()
	else:
		Events.card_keyword_tooltip_show.emit(ids, winner)


func populate_shop() -> void:
	for col: Node in shop_columns.get_children():
		col.queue_free()
	_kw_tip_menu = null
	_kw_tip_ids = PackedStringArray()
	Events.card_keyword_tooltip_hide.emit()

	var shop_card_array := _pick_shop_cards()
	var shop_relics_array := _pick_shop_relics()

	for i in range(3):
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_BEGIN
		col.add_theme_constant_override("separation", 10)
		shop_columns.add_child(col)

		if i < shop_card_array.size():
			var new_shop_card := SHOP_CARD.instantiate() as ShopCard
			col.add_child(new_shop_card)
			new_shop_card.card = shop_card_array[i]
			new_shop_card.call_deferred("set_modifier_context", modifier_handler)
			new_shop_card.gold_cost = _get_updated_shop_cost(new_shop_card.gold_cost)
			new_shop_card.update(run_stats)
		else:
			col.add_child(_make_spacer(ShopCard.SLOT_SIZE))

		if i < shop_relics_array.size():
			var new_shop_relic := SHOP_RELIC.instantiate() as ShopRelic
			col.add_child(new_shop_relic)
			new_shop_relic.relic = shop_relics_array[i]
			new_shop_relic.gold_cost = _get_updated_shop_cost(new_shop_relic.gold_cost)
			new_shop_relic.update(run_stats)
		else:
			col.add_child(_make_spacer(ShopRelic.SLOT_SIZE))


func _make_spacer(slot_size: Vector2) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = slot_size
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _pick_shop_cards() -> Array[Card]:
	var available_cards: Array[Card] = char_stats.draftable_cards.duplicate_cards()
	var wc := run_stats.common_weight if run_stats else RunStats.BASE_COMMON_WEIGHT
	var wu := run_stats.uncommon_weight if run_stats else RunStats.BASE_UNCOMMON_WEIGHT
	var wr := run_stats.rare_weight if run_stats else RunStats.BASE_RARE_WEIGHT
	return RNG.pick_weighted_distinct_cards(
		available_cards,
		mini(3, available_cards.size()),
		wc,
		wu,
		wr
	)


func _pick_shop_relics() -> Array[Relic]:
	var available_relics := shop_relics.filter(
		func(relic: Relic):
			var can_appear := relic.can_appear_as_reward(char_stats)
			var already_had_it := relic_handler.has_relic(relic.id)
			return can_appear and not already_had_it
	)
	RNG.array_shuffle(available_relics)
	return available_relics.slice(0, 3)


func _blink_timer_setup() -> void:
	blink_timer.wait_time = randf_range(1.0, 5.0)
	blink_timer.start()


func _update_items() -> void:
	for col: Node in shop_columns.get_children():
		for node: Node in col.get_children():
			if node is ShopCard:
				(node as ShopCard).update(run_stats)
			elif node is ShopRelic:
				(node as ShopRelic).update(run_stats)


func _update_item_costs() -> void:
	for col: Node in shop_columns.get_children():
		for node: Node in col.get_children():
			if node is ShopCard:
				var sc := node as ShopCard
				sc.gold_cost = _get_updated_shop_cost(sc.gold_cost)
				sc.update(run_stats)
			elif node is ShopRelic:
				var sr := node as ShopRelic
				sr.gold_cost = _get_updated_shop_cost(sr.gold_cost)
				sr.update(run_stats)


func _get_updated_shop_cost(original_cost: int) -> int:
	return modifier_handler.get_modified_value(original_cost, Modifier.Type.SHOP_COST)


func _on_back_button_pressed() -> void:
	Events.shop_exited.emit()


func _on_shop_card_bought(_card: Card, _gold_cost: int, _from: Control) -> void:
	_shop_card_purchase_flow(_card, _gold_cost, _from)


func _shop_card_purchase_flow(_card: Card, _gold_cost: int, _from: Control) -> void:
	var run := get_tree().get_first_node_in_group("run") as Run
	var from_center := _from.get_global_rect().get_center() if is_instance_valid(_from) else Vector2.ZERO
	if run:
		run.play_deck_gain_card_visual(_card, from_center)
	char_stats.deck.add_card(_card)
	run_stats.gold -= _gold_cost
	_update_items()


func _on_shop_relic_bought(relic: Relic, gold_cost: int) -> void:
	relic_handler.add_relic(relic)
	run_stats.gold -= gold_cost

	if relic is CouponsRelic:
		var coupons_relic := relic as CouponsRelic
		coupons_relic.add_shop_modifier(self)
		_update_item_costs()
	else:
		_update_items()


func _on_blink_timer_timeout() -> void:
	shop_keeper_animation.play("blink")
	_blink_timer_setup()
