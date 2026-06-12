class_name Shop
extends CardPreviewListHover

const SHOP_CARD = preload("res://scenes/shop/shop_card.tscn")
const SHOP_RELIC = preload("res://scenes/shop/shop_relic.tscn")
const SHOP_POTION = preload("res://scenes/shop/shop_potion.tscn")
const POTION_REWARD_POOL := preload("res://potions/potion_reward_pool.tres")
const REMOVE_CARD_UNAVAILABLE_TEXT := "感谢惠顾！"
const DECK_PICKER_OVERLAY := preload("res://scenes/ui/deck_picker_overlay.tscn")

const SHOP_CARD_COUNT := 5
const SHOP_RELIC_COUNT := 3
const SHOP_POTION_COUNT := 3
## listing 卡面原尺寸（与 card_visuals.tscn 一致）
const LISTING_CARD_VISUAL_SIZE := Vector2(210.0, 310.0)
const SHOP_ITEM_VBOX_SEP := 4
const SHOP_ITEM_LAYOUT_DONE_META := &"shop_item_layout_done"
const SHOP_SLOT_BLOCK_SIZE_META := &"shop_slot_block_size"
const SHOP_POTION_PRICE_FACTOR := 0.5
const REMOVE_CARD_BASE_COST := 75
const REMOVE_CARD_COST_STEP := 25

@export var shop_relics: Array[Relic]
@export var char_stats: CharacterStats
@export var run_stats: RunStats
@export var relic_handler: RelicHandler
@export var potion_handler: PotionHandler

@onready var shop_content: Control = $UILayer/ShopContent
@onready var remove_card_button: Button = %RemoveCardButton
@onready var remove_card_title: Label = %RemoveCardTitle
@onready var remove_card_price_row: HBoxContainer = %RemoveCardPriceRow
@onready var remove_card_price_label: Label = %RemoveCardPrice
@onready var back_button: Button = %BackButton
@onready var shop_keeper_animation: AnimationPlayer = %ShopkeeperAnimation

var _card_slot_nodes: Array[ShopLayoutSlot] = []
var _relic_slot_nodes: Array[ShopLayoutSlot] = []
var _potion_slot_nodes: Array[ShopLayoutSlot] = []
@onready var blink_timer: Timer = %BlinkTimer
@onready var modifier_handler: ModifierHandler = $ModifierHandler

var _shop_remove_used_this_visit := false
var _card_slots: Array = []
var _relic_slots: Array = []
var _potion_slots: Array = []
var _pending_sold_apply_data: Dictionary = {}


func gather_listing_card_menus_for_keyword_tooltip() -> Array[CardMenuUI]:
	var out: Array[CardMenuUI] = []
	for slot in _card_slots:
		var sc := slot as ShopCard
		if sc == null or not is_instance_valid(sc) or sc.is_sold():
			continue
		var m := sc.current_card_ui
		if m != null and is_instance_valid(m):
			out.append(m)
	return out


func _ready() -> void:
	_card_slot_nodes = [%CardSlot0, %CardSlot1, %CardSlot2, %CardSlot3, %CardSlot4]
	_relic_slot_nodes = [%RelicSlot0, %RelicSlot1, %RelicSlot2]
	_potion_slot_nodes = [%PotionSlot0, %PotionSlot1, %PotionSlot2]
	super._ready()
	_apply_pass_through_mouse_filters()
	Events.shop_card_bought.connect(_on_shop_card_bought)
	Events.shop_relic_bought.connect(_on_shop_relic_bought)
	Events.shop_potion_bought.connect(_on_shop_potion_bought)
	_connect_shop_refresh_signals()
	_blink_timer_setup()
	blink_timer.timeout.connect(_on_blink_timer_timeout)


func _connect_shop_refresh_signals() -> void:
	if run_stats != null and not run_stats.gold_changed.is_connected(_on_shop_run_stats_changed):
		run_stats.gold_changed.connect(_on_shop_run_stats_changed)
	if potion_handler != null and not potion_handler.slots_changed.is_connected(_on_shop_potion_slots_changed):
		potion_handler.slots_changed.connect(_on_shop_potion_slots_changed)


func _on_shop_run_stats_changed() -> void:
	_update_items()
	_refresh_remove_card_button()


func _on_shop_potion_slots_changed() -> void:
	_update_items()


func populate_shop(is_reload: bool = false) -> void:
	_connect_shop_refresh_signals()
	_clear_shop_rows()
	reset_listing_keyword_tooltip_state()
	_shop_remove_used_this_visit = false

	var run := get_tree().get_first_node_in_group("run") as Run

	if is_reload and run != null and run.can_restore_shop_pending():
		var data := run.get_shop_pending_data()
		if data.get("format_version", 0) >= 2:
			_shop_remove_used_this_visit = int(data.get("remove_count", 0)) >= 1
			_build_shop_from_pending(data)
			return

	var shop_cards := _pick_shop_cards()
	var shop_relics_array := _pick_shop_relics()
	var shop_potions_array := _pick_shop_potions()
	_build_shop_slots(
		shop_cards,
		shop_relics_array,
		shop_potions_array,
		PackedInt32Array(),
		PackedInt32Array(),
		PackedInt32Array(),
		true
	)
	if run != null:
		run.persist_shop_pending(
			_card_ids_from(shop_cards),
			_relic_ids_from(shop_relics_array),
			_potion_ids_from(shop_potions_array),
			_collect_card_costs(),
			_collect_relic_costs(),
			_collect_potion_costs(),
			_collect_card_sold_flags(),
			_collect_relic_sold_flags(),
			_collect_potion_sold_flags(),
			_shop_remove_pending_flag()
		)


func _shop_remove_pending_flag() -> int:
	return 1 if _shop_remove_used_this_visit else 0


func _clear_shop_rows() -> void:
	_card_slots.clear()
	_relic_slots.clear()
	_potion_slots.clear()
	for slot: ShopLayoutSlot in _card_slot_nodes:
		if slot != null:
			slot.clear_runtime_items()
	for slot: ShopLayoutSlot in _relic_slot_nodes:
		if slot != null:
			slot.clear_runtime_items()
	for slot: ShopLayoutSlot in _potion_slot_nodes:
		if slot != null:
			slot.clear_runtime_items()


func _build_shop_from_pending(data: Dictionary) -> void:
	var cards: Array[Card] = GameContent.load_cards_by_ids(data.get("card_ids", PackedStringArray()))
	var relics: Array[Relic] = []
	for rid: String in data.get("relic_ids", PackedStringArray()):
		var r := GameContent.load_relic_template(rid)
		if r != null:
			relics.append(r)
	var potions: Array[Potion] = []
	for pid: String in data.get("potion_ids", PackedStringArray()):
		var p := GameContent.load_potion_template(pid)
		if p != null:
			potions.append(p)
	_pending_sold_apply_data = data
	_build_shop_slots(
		cards,
		relics,
		potions,
		data.get("card_costs", PackedInt32Array()),
		data.get("relic_costs", PackedInt32Array()),
		data.get("potion_costs", PackedInt32Array()),
		false
	)


func _build_shop_slots(
	shop_card_array: Array[Card],
	shop_relics_array: Array[Relic],
	shop_potions_array: Array[Potion],
	card_costs: PackedInt32Array,
	relic_costs: PackedInt32Array,
	potion_costs: PackedInt32Array,
	apply_price_modifiers: bool
) -> void:
	_clear_shop_rows()
	_build_cards_row(shop_card_array, card_costs, apply_price_modifiers)
	_build_items_block(shop_relics_array, shop_potions_array, relic_costs, potion_costs, apply_price_modifiers)
	_refresh_remove_card_button()
	_apply_pending_sold_flags()


func _apply_pending_sold_flags() -> void:
	if _pending_sold_apply_data.is_empty():
		return
	var data := _pending_sold_apply_data
	_pending_sold_apply_data = {}
	var card_sold: PackedInt32Array = data.get("card_sold", PackedInt32Array())
	var relic_sold: PackedInt32Array = data.get("relic_sold", PackedInt32Array())
	var potion_sold: PackedInt32Array = data.get("potion_sold", PackedInt32Array())
	for i: int in range(mini(card_sold.size(), _card_slots.size())):
		if int(card_sold[i]) == 1 and _card_slots[i] != null:
			(_card_slots[i] as ShopCard).mark_as_sold()
	for i: int in range(mini(relic_sold.size(), _relic_slots.size())):
		if int(relic_sold[i]) == 1 and _relic_slots[i] != null:
			(_relic_slots[i] as ShopRelic).mark_as_sold()
	for i: int in range(mini(potion_sold.size(), _potion_slots.size())):
		if int(potion_sold[i]) == 1 and _potion_slots[i] != null:
			(_potion_slots[i] as ShopPotion).mark_as_sold()


func _build_cards_row(
	shop_card_array: Array[Card],
	card_costs: PackedInt32Array,
	apply_price_modifiers: bool
) -> void:
	for col_i: int in range(SHOP_CARD_COUNT):
		var slot := _card_slot_nodes[col_i] if col_i < _card_slot_nodes.size() else null
		if slot == null:
			_card_slots.append(null)
			continue
		if col_i < shop_card_array.size():
			var new_shop_card := SHOP_CARD.instantiate() as ShopCard
			if col_i < card_costs.size():
				new_shop_card.configure_cost(int(card_costs[col_i]))
			else:
				new_shop_card.gold_cost = _get_card_price_by_rarity(shop_card_array[col_i].rarity)
			slot.mount_item(new_shop_card)
			new_shop_card.card = shop_card_array[col_i]
			new_shop_card.set_modifier_context(modifier_handler)
			if apply_price_modifiers:
				new_shop_card.gold_cost = _get_updated_shop_cost(new_shop_card.gold_cost)
			new_shop_card.update(run_stats)
			_card_slots.append(new_shop_card)
		else:
			_card_slots.append(null)


func _build_items_block(
	shop_relics_array: Array[Relic],
	shop_potions_array: Array[Potion],
	relic_costs: PackedInt32Array,
	potion_costs: PackedInt32Array,
	apply_price_modifiers: bool
) -> void:
	_build_relics_center(shop_relics_array, relic_costs, apply_price_modifiers)
	_build_potions_center(shop_potions_array, potion_costs, apply_price_modifiers)


func _build_relics_center(
	shop_relics_array: Array[Relic],
	relic_costs: PackedInt32Array,
	apply_price_modifiers: bool
) -> void:
	for i: int in range(SHOP_RELIC_COUNT):
		var slot := _relic_slot_nodes[i] if i < _relic_slot_nodes.size() else null
		if slot == null:
			_relic_slots.append(null)
			continue
		if i < shop_relics_array.size():
			var new_shop_relic := SHOP_RELIC.instantiate() as ShopRelic
			if i < relic_costs.size():
				new_shop_relic.configure_cost(int(relic_costs[i]))
			else:
				new_shop_relic.configure_cost(
					_get_shop_relic_list_price(shop_relics_array[i])
				)
			slot.mount_item(new_shop_relic)
			new_shop_relic.relic = shop_relics_array[i]
			if apply_price_modifiers:
				new_shop_relic.gold_cost = _get_updated_shop_cost(new_shop_relic.gold_cost)
			new_shop_relic.update(run_stats)
			_relic_slots.append(new_shop_relic)
		else:
			_relic_slots.append(null)


func _build_potions_center(
	shop_potions_array: Array[Potion],
	potion_costs: PackedInt32Array,
	apply_price_modifiers: bool
) -> void:
	var inventory_full := potion_handler != null and not potion_handler.has_empty_slot()
	for i: int in range(SHOP_POTION_COUNT):
		var slot := _potion_slot_nodes[i] if i < _potion_slot_nodes.size() else null
		if slot == null:
			_potion_slots.append(null)
			continue
		if i < shop_potions_array.size():
			var new_shop_potion := SHOP_POTION.instantiate() as ShopPotion
			if i < potion_costs.size():
				new_shop_potion.configure_cost(int(potion_costs[i]))
			else:
				new_shop_potion.configure_cost(
					_get_potion_price_by_rarity(shop_potions_array[i].rarity)
				)
			slot.mount_item(new_shop_potion)
			new_shop_potion.potion = shop_potions_array[i]
			new_shop_potion.set_inventory_full(inventory_full)
			if apply_price_modifiers:
				new_shop_potion.gold_cost = _get_updated_shop_cost(new_shop_potion.gold_cost)
			new_shop_potion.update(run_stats)
			new_shop_potion.mouse_filter = Control.MOUSE_FILTER_STOP
			_potion_slots.append(new_shop_potion)
		else:
			_potion_slots.append(null)


func _apply_pass_through_mouse_filters() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if shop_content:
		shop_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for slot: ShopLayoutSlot in _card_slot_nodes:
		if slot:
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for slot: ShopLayoutSlot in _relic_slot_nodes:
		if slot:
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for slot: ShopLayoutSlot in _potion_slot_nodes:
		if slot:
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if remove_card_button:
		remove_card_button.mouse_filter = Control.MOUSE_FILTER_STOP
	if back_button:
		back_button.mouse_filter = Control.MOUSE_FILTER_STOP


func _is_remove_card_service_available() -> bool:
	return not _shop_remove_used_this_visit


func _get_global_shop_remove_count() -> int:
	if run_stats == null:
		return 0
	return run_stats.shop_card_removals


func _get_remove_card_cost() -> int:
	var raw := REMOVE_CARD_BASE_COST + REMOVE_CARD_COST_STEP * _get_global_shop_remove_count()
	return _get_updated_shop_cost(raw)


func _refresh_remove_card_button() -> void:
	if (
		remove_card_button == null
		or remove_card_title == null
		or remove_card_price_row == null
		or remove_card_price_label == null
		or run_stats == null
		or char_stats == null
	):
		return
	if not _is_remove_card_service_available():
		remove_card_title.text = REMOVE_CARD_UNAVAILABLE_TEXT
		remove_card_price_row.hide()
		remove_card_button.disabled = true
		remove_card_title.remove_theme_color_override("font_color")
		remove_card_price_label.remove_theme_color_override("font_color")
		return
	var cost := _get_remove_card_cost()
	var can_afford := run_stats.gold >= cost
	var can_remove := char_stats.deck.cards.size() > 1
	var can_use := can_afford and can_remove
	remove_card_title.text = "移除一张牌"
	remove_card_price_row.show()
	remove_card_price_label.text = str(cost)
	remove_card_button.disabled = not can_use
	var price_color := Color.WHITE if can_use else Color.RED
	remove_card_title.remove_theme_color_override("font_color")
	remove_card_price_label.add_theme_color_override("font_color", price_color)


func _on_remove_card_pressed() -> void:
	if char_stats == null or run_stats == null:
		return
	if not _is_remove_card_service_available():
		return
	var cost := _get_remove_card_cost()
	if run_stats.gold < cost or char_stats.deck.cards.size() <= 1:
		return
	var overlay := DeckPickerOverlay.open_on_tree(get_tree())
	overlay.setup(char_stats.deck, 1, Callable(), "选择要从牌组移除的一张牌。")
	var indices: Array = await overlay.pick_confirmed
	if indices.is_empty():
		_refresh_remove_card_button()
		return
	var deck_index: int = int(indices[0])
	if deck_index < 0 or deck_index >= char_stats.deck.cards.size():
		_refresh_remove_card_button()
		return
	var removed: Card = char_stats.deck.remove_card_at(deck_index)
	run_stats.gold -= cost
	run_stats.shop_card_removals += 1
	_shop_remove_used_this_visit = true
	var run := get_tree().get_first_node_in_group("run") as Run
	if run and removed:
		await run.play_deck_remove_card_shrink_remove_and_wait(removed)
	_update_items()
	_refresh_remove_card_button()
	_sync_shop_pending()



func _get_card_price_by_rarity(rarity: Card.Rarity) -> int:
	match rarity:
		Card.Rarity.COMMON:
			return RNG.instance.randi_range(50, 100)
		Card.Rarity.UNCOMMON:
			return RNG.instance.randi_range(80, 170)
		Card.Rarity.RARE:
			return RNG.instance.randi_range(100, 250)
		_:
			return RNG.instance.randi_range(100, 300)


func _get_shop_relic_list_price(relic: Relic) -> int:
	if relic != null and relic.id == "premium_pack":
		return 328
	return _get_relic_price_by_rarity(relic.rarity)


func _get_relic_price_by_rarity(rarity: Relic.Rarity) -> int:
	match rarity:
		Relic.Rarity.COMMON:
			return RNG.instance.randi_range(100, 160)
		Relic.Rarity.UNCOMMON:
			return RNG.instance.randi_range(160, 230)
		Relic.Rarity.RARE:
			return RNG.instance.randi_range(230, 320)
		Relic.Rarity.SHOP:
			return RNG.instance.randi_range(180, 260)
		_:
			return RNG.instance.randi_range(100, 300)


func _scale_potion_shop_price(base_price: int) -> int:
	return maxi(1, int(round(float(base_price) * SHOP_POTION_PRICE_FACTOR)))


func _get_potion_price_by_rarity(rarity: Potion.Rarity) -> int:
	var base := 0
	match rarity:
		Potion.Rarity.COMMON:
			base = RNG.instance.randi_range(80, 120)
		Potion.Rarity.UNCOMMON:
			base = RNG.instance.randi_range(120, 180)
		Potion.Rarity.RARE:
			base = RNG.instance.randi_range(180, 260)
		Potion.Rarity.SPECIAL:
			base = RNG.instance.randi_range(200, 280)
		_:
			base = RNG.instance.randi_range(80, 150)
	return _scale_potion_shop_price(base)


func _make_spacer(slot_size: Vector2) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = slot_size
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _pick_shop_cards() -> Array[Card]:
	var available_cards: Array[Card] = char_stats.draftable_cards.duplicate_cards()
	var floors_climbed := 0
	var run := get_tree().get_first_node_in_group("run") as Run
	if run != null and run.save_data != null:
		floors_climbed = run.save_data.floors_climbed
	var weights := run_stats.get_dynamic_weights(floors_climbed) if run_stats else {
		"common": RunStats.BASE_COMMON_WEIGHT,
		"uncommon": RunStats.BASE_UNCOMMON_WEIGHT,
		"rare": RunStats.BASE_RARE_WEIGHT,
	}
	return RNG.pick_weighted_distinct_cards(
		available_cards,
		mini(SHOP_CARD_COUNT, available_cards.size()),
		weights.common,
		weights.uncommon,
		weights.rare
	)


func _pick_shop_relics() -> Array[Relic]:
	var available_relics := shop_relics.filter(
		func(relic: Relic):
			if not GameContent.is_relic_enabled_in_game(relic.id):
				return false
			var can_appear := relic.can_appear_in_shop(char_stats)
			var already_had_it := relic_handler.has_relic(relic.id)
			return can_appear and not already_had_it
	)
	if available_relics.is_empty():
		return []
	var weighted_pool: Array[Relic] = []
	for relic: Relic in available_relics:
		if (
			relic.rarity == Relic.Rarity.COMMON
			or relic.rarity == Relic.Rarity.UNCOMMON
			or relic.rarity == Relic.Rarity.RARE
			or relic.rarity == Relic.Rarity.SHOP
		):
			weighted_pool.append(relic)
	var act_number := 1
	var run := get_tree().get_first_node_in_group("run") as Run
	if run != null and run.save_data != null:
		act_number = run.save_data.act_number
	var weights := run_stats.get_relic_rarity_weights(act_number) if run_stats else {
		"common": RunStats.RELIC_COMMON_WEIGHT,
		"uncommon": RunStats.RELIC_UNCOMMON_WEIGHT,
		"rare": RunStats.RELIC_RARE_WEIGHT,
	}
	return RNG.pick_weighted_distinct_relics(
		weighted_pool,
		mini(SHOP_RELIC_COUNT, weighted_pool.size()),
		weights.common,
		weights.uncommon,
		weights.rare,
		true
	)


func _pick_shop_potions() -> Array[Potion]:
	if POTION_REWARD_POOL == null or POTION_REWARD_POOL.potions.is_empty():
		return []
	var allowed_ids: Dictionary = {}
	var pool := POTION_REWARD_POOL.potions
	for i: int in range(pool.size()):
		var entry = pool[i]
		if entry == null:
			continue
		var pid: String = entry.id
		if not pid.is_empty():
			allowed_ids[pid] = true
	var available: Array[Potion] = []
	for potion: Potion in GameContent.load_all_potion_templates():
		if allowed_ids.has(potion.id):
			available.append(potion)
	if available.is_empty():
		return []
	var act_number := 1
	var run := get_tree().get_first_node_in_group("run") as Run
	if run != null and run.save_data != null:
		act_number = run.save_data.act_number
	var weights := run_stats.get_relic_rarity_weights(act_number) if run_stats else {
		"common": RunStats.RELIC_COMMON_WEIGHT,
		"uncommon": RunStats.RELIC_UNCOMMON_WEIGHT,
		"rare": RunStats.RELIC_RARE_WEIGHT,
	}
	return RNG.pick_weighted_distinct_potions(
		available,
		mini(SHOP_POTION_COUNT, available.size()),
		weights.common,
		weights.uncommon,
		weights.rare
	)


func _card_ids_from(cards: Array[Card]) -> PackedStringArray:
	var out := PackedStringArray()
	for c: Card in cards:
		out.append(c.id)
	while out.size() < SHOP_CARD_COUNT:
		out.append("")
	return out


func _relic_ids_from(relics: Array[Relic]) -> PackedStringArray:
	var out := PackedStringArray()
	for r: Relic in relics:
		out.append(r.id)
	while out.size() < SHOP_RELIC_COUNT:
		out.append("")
	return out


func _potion_ids_from(potions: Array[Potion]) -> PackedStringArray:
	var out := PackedStringArray()
	for i: int in range(potions.size()):
		var p: Potion = potions[i]
		if p != null:
			out.append(p.id)
	while out.size() < SHOP_POTION_COUNT:
		out.append("")
	return out


func _collect_card_costs() -> PackedInt32Array:
	var out := PackedInt32Array()
	for slot in _card_slots:
		var sc := slot as ShopCard
		if sc != null and is_instance_valid(sc):
			out.append(sc.gold_cost)
		else:
			out.append(0)
	return out


func _collect_relic_costs() -> PackedInt32Array:
	var out := PackedInt32Array()
	for slot in _relic_slots:
		var sr := slot as ShopRelic
		if sr != null and is_instance_valid(sr):
			out.append(sr.gold_cost)
		else:
			out.append(0)
	return out


func _collect_potion_costs() -> PackedInt32Array:
	var out := PackedInt32Array()
	for slot in _potion_slots:
		var sp := slot as ShopPotion
		if sp != null and is_instance_valid(sp):
			out.append(sp.gold_cost)
		else:
			out.append(0)
	return out


func _collect_card_sold_flags() -> PackedInt32Array:
	var out := PackedInt32Array()
	for slot in _card_slots:
		var sc := slot as ShopCard
		if sc != null and is_instance_valid(sc) and sc.is_sold():
			out.append(1)
		else:
			out.append(0)
	return out


func _collect_relic_sold_flags() -> PackedInt32Array:
	var out := PackedInt32Array()
	for slot in _relic_slots:
		var sr := slot as ShopRelic
		if sr != null and is_instance_valid(sr) and sr.is_sold():
			out.append(1)
		else:
			out.append(0)
	return out


func _collect_potion_sold_flags() -> PackedInt32Array:
	var out := PackedInt32Array()
	for slot in _potion_slots:
		var sp := slot as ShopPotion
		if sp != null and is_instance_valid(sp) and sp.is_sold():
			out.append(1)
		else:
			out.append(0)
	return out


func _sync_shop_pending() -> void:
	var run := get_tree().get_first_node_in_group("run") as Run
	if run == null or run.save_data == null:
		return
	run.persist_shop_pending(
		run.save_data.pending_card_template_ids,
		run.save_data.pending_relic_ids,
		run.save_data.pending_potion_ids,
		_collect_card_costs(),
		_collect_relic_costs(),
		_collect_potion_costs(),
		_collect_card_sold_flags(),
		_collect_relic_sold_flags(),
		_collect_potion_sold_flags(),
		_shop_remove_pending_flag()
	)


func _blink_timer_setup() -> void:
	blink_timer.wait_time = randf_range(1.0, 5.0)
	blink_timer.start()


func _update_items() -> void:
	var inventory_full := potion_handler != null and not potion_handler.has_empty_slot()
	for slot in _card_slots:
		var sc := slot as ShopCard
		if sc != null and is_instance_valid(sc):
			sc.update(run_stats)
	for slot in _relic_slots:
		var sr := slot as ShopRelic
		if sr != null and is_instance_valid(sr):
			sr.update(run_stats)
	for slot in _potion_slots:
		var sp := slot as ShopPotion
		if sp != null and is_instance_valid(sp):
			sp.set_inventory_full(inventory_full)
			sp.update(run_stats)


func _update_item_costs() -> void:
	for slot in _card_slots:
		var sc := slot as ShopCard
		if sc != null and is_instance_valid(sc):
			sc.gold_cost = _get_updated_shop_cost(sc.gold_cost)
			sc.update(run_stats)
	for slot in _relic_slots:
		var sr := slot as ShopRelic
		if sr != null and is_instance_valid(sr):
			sr.gold_cost = _get_updated_shop_cost(sr.gold_cost)
			sr.update(run_stats)
	for slot in _potion_slots:
		var sp := slot as ShopPotion
		if sp != null and is_instance_valid(sp):
			sp.gold_cost = _get_updated_shop_cost(sp.gold_cost)
			sp.update(run_stats)
	_refresh_remove_card_button()


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
	_refresh_remove_card_button()


func _on_shop_relic_bought(relic: Relic, gold_cost: int) -> void:
	await relic_handler.add_relic_async(relic)
	run_stats.gold -= gold_cost
	_sync_shop_pending()
	if relic is VipCardRelic:
		var vip_on_bar := _find_vip_card_on_handler()
		if vip_on_bar != null:
			vip_on_bar.add_shop_modifier(self)
		_update_item_costs()
	else:
		_update_items()
	_refresh_remove_card_button()


func _on_shop_potion_bought(potion: Potion, gold_cost: int) -> void:
	if potion_handler == null or potion == null:
		return
	if not potion_handler.add_potion(potion.duplicate(true) as Potion):
		return
	run_stats.gold -= gold_cost
	_sync_shop_pending()
	_update_items()
	_refresh_remove_card_button()


func _find_vip_card_on_handler() -> VipCardRelic:
	if relic_handler == null:
		return null
	for r: Relic in relic_handler.get_all_relics():
		if r is VipCardRelic:
			return r as VipCardRelic
	return null


func _on_blink_timer_timeout() -> void:
	shop_keeper_animation.play("blink")
	_blink_timer_setup()
