class_name InfiniteStatus
extends Status

var _owner: Node


func get_tooltip() -> String:
	return tooltip % format_counter_for_tooltip(stacks)


func initialize_status(target: Node) -> void:
	_owner = target
	if not Events.card_exhausted.is_connected(_on_card_exhausted):
		Events.card_exhausted.connect(_on_card_exhausted)


func deactivate_status(_target: Node) -> void:
	if Events.card_exhausted.is_connected(_on_card_exhausted):
		Events.card_exhausted.disconnect(_on_card_exhausted)
	_owner = null


func _on_card_exhausted(_card: Card) -> void:
	if stacks <= 0:
		return
	if Events.is_combat_ended():
		return
	if not is_instance_valid(_owner) or not (_owner is Player):
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var ph := tree.get_first_node_in_group("player_handler") as PlayerHandler
	if ph == null or not is_instance_valid(ph.character):
		return
	ph.character.gain_mana(stacks)
