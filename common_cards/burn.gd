extends Card

@export var end_turn_damage := 2


func is_unplayable() -> bool:
	return true


func on_end_turn_in_hand(player: Player, _handler: PlayerHandler, card_ui: CardUI) -> void:
	if player == null or Events.is_combat_ended():
		return
	if is_instance_valid(card_ui):
		var viewport := card_ui.get_viewport()
		if viewport != null:
			var center := viewport.get_visible_rect().size * 0.5 - card_ui.size * 0.5
			var tween := card_ui.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(card_ui, "global_position", center, 0.18)
			await tween.finished
	var dmg := DamageEffect.create_fixed(end_turn_damage)
	dmg.execute([player])
	await player.get_tree().create_timer(0.12).timeout