extends Relic

@export var draw_amount := 1

var _owner: RelicUI
var _last_type := -1
var _same_type_streak := 0


func initialize_relic(owner: RelicUI) -> void:
	_owner = owner
	if not Events.card_play_finished.is_connected(_on_card_play_finished):
		Events.card_play_finished.connect(_on_card_play_finished)


func deactivate_relic(_owner_ui: RelicUI) -> void:
	if Events.card_play_finished.is_connected(_on_card_play_finished):
		Events.card_play_finished.disconnect(_on_card_play_finished)
	_owner = null
	_last_type = -1
	_same_type_streak = 0


func _on_card_play_finished(card: Card) -> void:
	if card == null or Events.is_combat_ended():
		return
	if int(card.type) == _last_type:
		_same_type_streak += 1
	else:
		_last_type = int(card.type)
		_same_type_streak = 1
	if _same_type_streak < 2 or _same_type_streak % 2 != 0:
		return
	var ph := _player_handler()
	if ph == null:
		return
	ph.draw_cards(draw_amount, false, false, false)
	if is_instance_valid(_owner):
		_owner.flash()


func _player_handler() -> PlayerHandler:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group("player_handler") as PlayerHandler
