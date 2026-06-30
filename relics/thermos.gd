extends Relic

@export var extra_slots := 2


func apply_persistent_pickup_on_acquire(_run: Node) -> void:
	var run := _run as Run
	if run == null or run.potion_handler == null:
		return
	run.potion_handler.add_empty_slots(extra_slots)


func revert_persistent_pickup_on_rollback(_ch: CharacterStats) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var run := tree.get_first_node_in_group("run") as Run
	if run == null or run.potion_handler == null:
		return
	run.potion_handler.remove_empty_slots_from_end(extra_slots)