class_name CardRewards
extends ColorRect

## picked_menu 为选中的 CardMenuUI（会从本面板摘下再飞入牌库）；跳过奖励时发 null
signal card_reward_selected(picked_menu: Variant, from_global: Vector2)

const CARD_MENU_UI = preload("res://scenes/ui/card_menu_ui.tscn")

@export var rewards: Array[Card] : set = set_rewards

@onready var cards: HBoxContainer = %Cards
@onready var skip_card_reward: Button = %SkipCardReward

var _kw_tip_menu: CardMenuUI = null
var _kw_tip_ids: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_clear_rewards()
	set_process(true)

	skip_card_reward.pressed.connect(
		func():
			card_reward_selected.emit(null, Vector2.ZERO)
			queue_free()
	)


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
	for ch: Node in cards.get_children():
		if not ch is CardMenuUI:
			continue
		var m := ch as CardMenuUI
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
	_sync_reward_listing_keyword_tooltip(winner, tip_ids)


func _kw_tip_ids_equal(a: PackedStringArray, b: PackedStringArray) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if a[i] != b[i]:
			return false
	return true


func _sync_reward_listing_keyword_tooltip(winner: CardMenuUI, ids: PackedStringArray) -> void:
	if winner == _kw_tip_menu and _kw_tip_ids_equal(ids, _kw_tip_ids):
		return
	_kw_tip_menu = winner
	_kw_tip_ids = ids.duplicate() if winner != null else PackedStringArray()
	if winner == null:
		Events.card_keyword_tooltip_hide.emit()
	else:
		Events.card_keyword_tooltip_show.emit(ids, winner)


func _clear_rewards() -> void:
	_kw_tip_menu = null
	_kw_tip_ids = PackedStringArray()
	Events.card_keyword_tooltip_hide.emit()
	for card: Node in cards.get_children():
		card.queue_free()


func _on_reward_tile_pressed(menu: CardMenuUI, _card: Card) -> void:
	var from := menu.get_global_rect().get_center()
	var p := menu.get_parent()
	if p:
		p.remove_child(menu)
	card_reward_selected.emit(menu, from)
	queue_free()


func set_rewards(new_cards: Array[Card]) -> void:
	rewards = new_cards

	if not is_node_ready():
		await ready

	_clear_rewards()
	for card: Card in rewards:
		var new_card := CARD_MENU_UI.instantiate() as CardMenuUI
		new_card.use_listing_hover_zoom = true
		cards.add_child(new_card)
		new_card.card = card
		new_card.card_pick_pressed.connect(func(c: Card) -> void: _on_reward_tile_pressed(new_card, c))
