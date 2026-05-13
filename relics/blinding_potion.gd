extends Relic


func apply_persistent_pickup_on_acquire(_run: Node) -> void:
	var run := _run as Run
	if run == null or not is_instance_valid(run.character):
		return
	run.character.max_mana += 1
	run.character.mana = run.character.max_mana
	run.character.stats_changed.emit()


func initialize_relic(_owner: RelicUI) -> void:
	pass


func activate_relic(owner: RelicUI) -> void:
	Events.intent_tooltip_hover_hide.emit()
	owner.get_tree().call_group("intent", "set", "modulate", Color.TRANSPARENT)


func deactivate_relic(owner: RelicUI) -> void:
	owner.get_tree().call_group("intent", "set", "modulate", Color.WHITE)
	var run := owner.get_tree().get_first_node_in_group("run") as Run
	if run == null or not is_instance_valid(run.character):
		return
	run.character.max_mana = maxi(1, run.character.max_mana - 1)
	run.character.mana = mini(run.character.mana, run.character.max_mana)
	run.character.stats_changed.emit()
