class_name Shop
extends CardPreviewListHover

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


func gather_listing_card_menus_for_keyword_tooltip() -> Array[CardMenuUI]:
	var out: Array[CardMenuUI] = []
	for col: Node in shop_columns.get_children():
		for ch: Node in col.get_children():
			if not ch is ShopCard:
				continue
			var sc := ch as ShopCard
			if sc.is_sold():
				continue
			var m := sc.current_card_ui
			if m != null and is_instance_valid(m):
				out.append(m)
	return out


func _ready() -> void:
	super._ready()
	for col: Node in shop_columns.get_children():
		col.queue_free()

	Events.shop_card_bought.connect(_on_shop_card_bought)
	Events.shop_relic_bought.connect(_on_shop_relic_bought)

	_blink_timer_setup()
	blink_timer.timeout.connect(_on_blink_timer_timeout)


func populate_shop(is_reload: bool = false) -> void:
	for col: Node in shop_columns.get_children():
		col.queue_free()
	reset_listing_keyword_tooltip_state()

	var run := get_tree().get_first_node_in_group("run") as Run
	
	# 重载时：生成全新的商店商品，不恢复售出状态
	# 玩家状态（金币、遗物、卡牌）已由场景进入快照恢复
	if is_reload:
		var shop_card_array := _pick_shop_cards()
		var shop_relics_array := _pick_shop_relics()
		_build_shop_slots(shop_card_array, shop_relics_array, PackedInt32Array(), PackedInt32Array(), true)
		return

	var shop_card_array := _pick_shop_cards()
	var shop_relics_array := _pick_shop_relics()
	_build_shop_slots(shop_card_array, shop_relics_array, PackedInt32Array(), PackedInt32Array(), true)
	if run != null:
		run.persist_shop_pending(
			_card_ids_from(shop_card_array),
			_relic_ids_from(shop_relics_array),
			_collect_card_costs(),
			_collect_relic_costs(),
			PackedInt32Array([0, 0, 0]),
			PackedInt32Array([0, 0, 0])
		)


func _build_shop_from_pending(data: Dictionary, is_fresh_enter: bool = false) -> void:
	var cards: Array[Card] = GameContent.load_cards_by_ids(data.get("card_ids", PackedStringArray()))
	var relics: Array[Relic] = []
	for rid: String in data.get("relic_ids", PackedStringArray()):
		var r := GameContent.load_relic_template(rid)
		if r != null:
			relics.append(r)
	_build_shop_slots(
		cards,
		relics,
		data.get("card_costs", PackedInt32Array()),
		data.get("relic_costs", PackedInt32Array()),
		false
	)
	# 只有非新进入时才恢复售出状态（即游戏内正常流程）
	# 重载时（刚进入场景状态）不恢复售出状态，因为场景快照已恢复金币
	if is_fresh_enter:
		return
	
	var card_sold: PackedInt32Array = data.get("card_sold", PackedInt32Array())
	var relic_sold: PackedInt32Array = data.get("relic_sold", PackedInt32Array())
	var card_i := 0
	var relic_i := 0
	for col: Node in shop_columns.get_children():
		for node: Node in col.get_children():
			if node is ShopCard:
				if card_i < card_sold.size() and int(card_sold[card_i]) == 1:
					(node as ShopCard).mark_as_sold()
				card_i += 1
			elif node is ShopRelic:
				if relic_i < relic_sold.size() and int(relic_sold[relic_i]) == 1:
					(node as ShopRelic).mark_as_sold()
				relic_i += 1


func _build_shop_slots(
	shop_card_array: Array[Card],
	shop_relics_array: Array[Relic],
	card_costs: PackedInt32Array,
	relic_costs: PackedInt32Array,
	apply_price_modifiers: bool
) -> void:
	for i in range(3):
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_BEGIN
		col.add_theme_constant_override("separation", 10)
		shop_columns.add_child(col)

		if i < shop_card_array.size():
			var new_shop_card := SHOP_CARD.instantiate() as ShopCard
			if i < card_costs.size():
				new_shop_card.configure_cost(int(card_costs[i]))
			else:
				## 根据卡牌稀有度定价
				new_shop_card.gold_cost = _get_card_price_by_rarity(shop_card_array[i].rarity)
			col.add_child(new_shop_card)
			new_shop_card.card = shop_card_array[i]
			new_shop_card.call_deferred("set_modifier_context", modifier_handler)
			if apply_price_modifiers:
				new_shop_card.gold_cost = _get_updated_shop_cost(new_shop_card.gold_cost)
			new_shop_card.update(run_stats)
		else:
			col.add_child(_make_spacer(ShopCard.SLOT_SIZE))

		if i < shop_relics_array.size():
			var new_shop_relic := SHOP_RELIC.instantiate() as ShopRelic
			if i < relic_costs.size():
				new_shop_relic.configure_cost(int(relic_costs[i]))
			col.add_child(new_shop_relic)
			new_shop_relic.relic = shop_relics_array[i]
			if apply_price_modifiers:
				new_shop_relic.gold_cost = _get_updated_shop_cost(new_shop_relic.gold_cost)
			new_shop_relic.update(run_stats)
		else:
			col.add_child(_make_spacer(ShopRelic.SLOT_SIZE))


## 根据卡牌稀有度定价
func _get_card_price_by_rarity(rarity: Card.Rarity) -> int:
	match rarity:
		Card.Rarity.COMMON:
			return RNG.instance.randi_range(50, 100)
		Card.Rarity.UNCOMMON:
			return RNG.instance.randi_range(80, 170)
		Card.Rarity.RARE:
			return RNG.instance.randi_range(100, 250)
		_:
			return RNG.instance.randi_range(100, 300)  ## 默认


func _make_spacer(slot_size: Vector2) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = slot_size
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _pick_shop_cards() -> Array[Card]:
	var available_cards: Array[Card] = char_stats.draftable_cards.duplicate_cards()
	
	## 获取当前层数，应用动态稀有度权重
	var floors_climbed := 0
	var run := get_tree().get_first_node_in_group("run") as Run
	if run != null and run.save_data != null:
		floors_climbed = run.save_data.floors_climbed
	
	var weights := run_stats.get_dynamic_weights(floors_climbed) if run_stats else {
		"common": RunStats.BASE_COMMON_WEIGHT,
		"uncommon": RunStats.BASE_UNCOMMON_WEIGHT,
		"rare": RunStats.BASE_RARE_WEIGHT
	}
	
	return RNG.pick_weighted_distinct_cards(
		available_cards,
		mini(3, available_cards.size()),
		weights.common,
		weights.uncommon,
		weights.rare
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


func _card_ids_from(cards: Array[Card]) -> PackedStringArray:
	var out := PackedStringArray()
	for c: Card in cards:
		out.append(c.id)
	return out


func _relic_ids_from(relics: Array[Relic]) -> PackedStringArray:
	var out := PackedStringArray()
	for r: Relic in relics:
		out.append(r.id)
	return out


func _collect_card_costs() -> PackedInt32Array:
	var out := PackedInt32Array()
	for col: Node in shop_columns.get_children():
		for node: Node in col.get_children():
			if node is ShopCard:
				out.append((node as ShopCard).gold_cost)
	return out


func _collect_relic_costs() -> PackedInt32Array:
	var out := PackedInt32Array()
	for col: Node in shop_columns.get_children():
		for node: Node in col.get_children():
			if node is ShopRelic:
				out.append((node as ShopRelic).gold_cost)
	return out


func _collect_sold_flags() -> Dictionary:
	var card_sold := PackedInt32Array()
	var relic_sold := PackedInt32Array()
	for col: Node in shop_columns.get_children():
		var card_slot := 0
		var relic_slot := 0
		for node: Node in col.get_children():
			if node is ShopCard:
				card_sold.append(1 if (node as ShopCard).is_sold() else 0)
				card_slot += 1
			elif node is ShopRelic:
				relic_sold.append(1 if (node as ShopRelic).is_sold() else 0)
				relic_slot += 1
	while card_sold.size() < 3:
		card_sold.append(0)
	while relic_sold.size() < 3:
		relic_sold.append(0)
	return {"card_sold": card_sold, "relic_sold": relic_sold}


func _sync_shop_pending() -> void:
	var run := get_tree().get_first_node_in_group("run") as Run
	if run == null or run.save_data == null:
		return
	var sold := _collect_sold_flags()
	run.persist_shop_pending(
		run.save_data.pending_card_template_ids,
		run.save_data.pending_relic_ids,
		_collect_card_costs(),
		_collect_relic_costs(),
		sold["card_sold"],
		sold["relic_sold"]
	)


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
	_sync_shop_pending()


func _shop_card_purchase_flow(_card: Card, _gold_cost: int, _from: Control) -> void:
	var run := get_tree().get_first_node_in_group("run") as Run
	var from_center := _from.get_global_rect().get_center() if is_instance_valid(_from) else Vector2.ZERO
	if run:
		run.play_deck_gain_card_visual(_card, from_center)
	char_stats.deck.add_card(_card)
	run_stats.gold -= _gold_cost
	_update_items()


func _on_shop_relic_bought(relic: Relic, gold_cost: int) -> void:
	await relic_handler.add_relic_async(relic)
	run_stats.gold -= gold_cost
	_sync_shop_pending()

	if relic is CouponsRelic:
		var coupons_relic := relic as CouponsRelic
		coupons_relic.add_shop_modifier(self)
		_update_item_costs()
	else:
		_update_items()


func _on_blink_timer_timeout() -> void:
	shop_keeper_animation.play("blink")
	_blink_timer_setup()
