class_name CardPileOpener
extends TextureButton

@export var counter: Label
@export var card_pile: CardPile : set = set_card_pile

var _bound_pile: CardPile


func set_card_pile(new_value: CardPile) -> void:
	if _bound_pile != null and _bound_pile.card_pile_size_changed.is_connected(_on_card_pile_size_changed):
		_bound_pile.card_pile_size_changed.disconnect(_on_card_pile_size_changed)
	card_pile = new_value
	_bound_pile = new_value
	if card_pile == null:
		if is_instance_valid(counter):
			counter.text = "0"
		return
	if not card_pile.card_pile_size_changed.is_connected(_on_card_pile_size_changed):
		card_pile.card_pile_size_changed.connect(_on_card_pile_size_changed)
	_on_card_pile_size_changed(card_pile.cards.size())
	
	
func _on_card_pile_size_changed(cards_amount: int) -> void:
	if not is_instance_valid(counter):
		return
	counter.text = str(cards_amount)
