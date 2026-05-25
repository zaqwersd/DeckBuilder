class_name DexterityStatus
extends Status


func get_tooltip() -> String:
	return tooltip % format_counter_for_tooltip(stacks)


static func get_bonus_from_player(player: Node) -> int:
	if not player is Player:
		return 0
	var status_handler: StatusHandler = player.get("status_handler")
	if status_handler == null:
		return 0
	var dex := status_handler.get_status_by_id("dexterity") as DexterityStatus
	if dex == null:
		return 0
	return maxi(0, dex.stacks)
