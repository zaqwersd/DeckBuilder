extends Card

const SELF_DAMAGE := 5


func get_default_tooltip() -> String:
	return tooltip_text


func get_updated_tooltip(
	_player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler, _combat_player: Node = null
) -> String:
	return tooltip_text


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	for t in targets:
		if t is Player:
			(t as Player).take_damage_final(SELF_DAMAGE)
			break
	var draw_effect := CardDrawEffect.new()
	draw_effect.cards_to_draw = 1
	await draw_effect.execute(targets)
