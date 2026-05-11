class_name ExhaustRandomEffect
extends Effect

var amount := 1


func execute(targets: Array[Node]) -> void:
	if targets.is_empty():
		return
		
	var player_handler := targets[0].get_tree().get_first_node_in_group("player_handler") as PlayerHandler
	
	if not player_handler:
		return
	
	var slots := player_handler.hand.get_children().duplicate()
	RNG.array_shuffle(slots)
	var chosen_slots := slots.slice(0, amount)
	
	for slot in chosen_slots:
		if is_instance_valid(slot):
			slot.queue_free()
