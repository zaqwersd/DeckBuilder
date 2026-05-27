extends Potion


func perform_use(targets: Array[Node]) -> void:
	if targets.is_empty():
		return
	var player := targets[0] as Player
	if player == null or not is_instance_valid(player.status_handler):
		return
	player.status_handler.remove_harmful_statuses()
