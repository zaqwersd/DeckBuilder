extends EnemyAction

const GHOST := preload("res://common_cards/ghost.tres")
@export var damage := 6
@export var erosion_intent: Intent


func get_planned_intents() -> Array[Intent]:
	var arr: Array[Intent] = []
	if intent:
		arr.append(intent)
	if erosion_intent:
		arr.append(erosion_intent)
	return arr


func update_planned_intents() -> void:
	update_intent_text()
	if erosion_intent:
		erosion_intent.display_number = Intent.NUMBER_HIDDEN
		erosion_intent.current_text = ""


func perform_action() -> void:
	if not enemy or not target:
		return
	var player := target as Player
	if not player:
		return
	var modified := player.modifier_handler.get_modified_value(damage, Modifier.Type.DMG_TAKEN)
	var final_dmg := enemy.modifier_handler.get_modified_value(modified, Modifier.Type.DMG_DEALT)
	var tw1 := create_tween().set_trans(Tween.TRANS_QUINT)
	var start := enemy.global_position
	var end := EnemyAction.attack_lunge_position(start)
	tw1.tween_property(enemy, "global_position", end, 0.4)
	await tw1.finished
	var dmg_eff := DamageEffect.new()
	dmg_eff.amount = final_dmg
	dmg_eff.sound = sound
	dmg_eff.execute([target])
	var cards: Array[Card] = [GHOST.duplicate() as Card, GHOST.duplicate() as Card]
	var fx: Node = player.get_tree().get_first_node_in_group("battle_card_fx")
	if fx and fx.is_inside_tree() and fx.has_method("animate_multi_insert_into_discard_pile"):
		fx.animate_multi_insert_into_discard_pile(cards, enemy.global_position, player.stats)
	else:
		for c in cards:
			player.stats.discard.add_card(c)
	var tw2 := create_tween().set_trans(Tween.TRANS_QUINT)
	tw2.tween_property(enemy, "global_position", start, 0.38)
	await tw2.finished
	var picker := enemy.enemy_action_picker
	if picker:
		picker.notify_picker_action_finished()
	Events.enemy_action_completed.emit(enemy)


func update_intent_text() -> void:
	var player := target as Player
	if not player or not enemy or not intent:
		return
	var modified := player.modifier_handler.get_modified_value(damage, Modifier.Type.DMG_TAKEN)
	var final_dmg := enemy.modifier_handler.get_modified_value(modified, Modifier.Type.DMG_DEALT)
	intent.set_attack_segments_display(final_dmg, 1)
