class_name EntangledStatus
extends Status


func get_tooltip() -> String:
	return tooltip % format_counter_for_tooltip(duration)


static func is_active_on(player: Player) -> bool:
	if player == null or player.status_handler == null:
		return false
	var st := player.status_handler.get_status_by_id("entangled")
	return st != null and st.duration > 0 and not st.awaits_turn_start


static func blocks_attack_card(card: Card, player: Player) -> bool:
	return card != null and card.type == Card.Type.ATTACK and is_active_on(player)
