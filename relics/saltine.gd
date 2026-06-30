extends Relic

@export var max_health_gain := 3

var _owner: RelicUI


func initialize_relic(owner: RelicUI) -> void:
	_owner = owner
	if not Events.deck_card_added.is_connected(_on_deck_card_added):
		Events.deck_card_added.connect(_on_deck_card_added)


func deactivate_relic(_owner_ui: RelicUI) -> void:
	if Events.deck_card_added.is_connected(_on_deck_card_added):
		Events.deck_card_added.disconnect(_on_deck_card_added)
	_owner = null


func _on_deck_card_added(_card: Card) -> void:
	var run := _current_run()
	if run == null or run.character == null:
		return
	run.character.max_health += max_health_gain
	if is_instance_valid(_owner):
		_owner.flash()


func _current_run() -> Run:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group("run") as Run