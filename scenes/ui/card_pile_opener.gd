class_name CardPileOpener
extends TextureButton

@export var counter: Label
@export var card_pile: CardPile : set = set_card_pile
@export var keyword_tooltip_id: String = ""

var _bound_pile: CardPile
var _counter_animation_active := false
var _pending_cards_amount := 0


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func set_card_pile(new_value: CardPile) -> void:
	if _bound_pile != null and _bound_pile.card_pile_size_changed.is_connected(_on_card_pile_size_changed):
		_bound_pile.card_pile_size_changed.disconnect(_on_card_pile_size_changed)
	card_pile = new_value
	_bound_pile = new_value
	if card_pile == null:
		_pending_cards_amount = 0
		_set_counter_text(0)
		return
	if not card_pile.card_pile_size_changed.is_connected(_on_card_pile_size_changed):
		card_pile.card_pile_size_changed.connect(_on_card_pile_size_changed)
	_on_card_pile_size_changed(card_pile.cards.size())
	
	
func _on_card_pile_size_changed(cards_amount: int) -> void:
	_pending_cards_amount = cards_amount
	if _counter_animation_active:
		return
	_set_counter_text(cards_amount)


func begin_counter_animation(start_amount: int) -> void:
	_counter_animation_active = true
	_set_counter_text(start_amount)


func set_counter_animation_amount(amount: int) -> void:
	if not _counter_animation_active:
		return
	_set_counter_text(amount)


func end_counter_animation() -> void:
	_counter_animation_active = false
	if card_pile:
		_pending_cards_amount = card_pile.cards.size()
	_set_counter_text(_pending_cards_amount)


func _set_counter_text(amount: int) -> void:
	if not is_instance_valid(counter):
		return
	counter.text = str(maxi(0, amount))


func _on_mouse_entered() -> void:
	if keyword_tooltip_id.strip_edges().is_empty():
		return
	Events.card_keyword_tooltip_show.emit(PackedStringArray([keyword_tooltip_id]), self)


func _on_mouse_exited() -> void:
	if keyword_tooltip_id.strip_edges().is_empty():
		return
	Events.card_keyword_tooltip_hide.emit()
