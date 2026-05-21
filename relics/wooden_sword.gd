extends Relic

@export var skills_required := 3
@export var damage := 5

var relic_ui: RelicUI
var skills_this_turn: int
var _map_exited_reset: Callable


func initialize_relic(owner: RelicUI) -> void:
	relic_ui = owner
	_map_exited_reset = _reset.unbind(1)
	Events.player_hand_drawn.connect(_reset)
	Events.map_exited.connect(_map_exited_reset)
	Events.card_played.connect(_on_card_played)
	_update_counter_display()


func deactivate_relic(_owner: RelicUI) -> void:
	if Events.player_hand_drawn.is_connected(_reset):
		Events.player_hand_drawn.disconnect(_reset)
	if Events.map_exited.is_connected(_map_exited_reset):
		Events.map_exited.disconnect(_map_exited_reset)
	if Events.card_played.is_connected(_on_card_played):
		Events.card_played.disconnect(_on_card_played)


func _reset() -> void:
	skills_this_turn = 0
	_update_counter_display()


func _update_counter_display() -> void:
	if is_instance_valid(relic_ui):
		relic_ui.set_counter_subscript(skills_this_turn)


func _on_card_played(card: Card) -> void:
	if card.type != Card.Type.SKILL:
		return
	
	skills_this_turn += 1
	_update_counter_display()
	
	if skills_this_turn % skills_required == 0:
		var enemies := relic_ui.get_tree().get_nodes_in_group("enemies")
		var damage_effect := DamageEffect.new()
		damage_effect.amount = damage
		damage_effect.receiver_modifier_type = Modifier.Type.NO_MODIFIER
		damage_effect.execute(enemies)
		
		relic_ui.flash()
		skills_this_turn = 0
		_update_counter_display()
