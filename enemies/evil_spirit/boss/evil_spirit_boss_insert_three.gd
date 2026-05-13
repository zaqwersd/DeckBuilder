extends EnemyAction

const GHOST := preload("res://common_cards/ghost.tres")
@export var erosion_intent: Intent


func get_planned_intents() -> Array[Intent]:
	if erosion_intent:
		return [erosion_intent]
	return super.get_planned_intents()


func update_planned_intents() -> void:
	if erosion_intent:
		erosion_intent.display_number = Intent.NUMBER_HIDDEN
		erosion_intent.current_text = ""


func perform_action() -> void:
	if not enemy or not target:
		return
	var player := target as Player
	if not player:
		return
	var cards: Array[Card] = []
	for _i in 3:
		cards.append(GHOST.duplicate() as Card)
	var fx: Node = player.get_tree().get_first_node_in_group("battle_card_fx")
	if fx and fx.is_inside_tree() and fx.has_method("animate_multi_insert_into_discard_pile"):
		fx.animate_multi_insert_into_discard_pile(cards, enemy.global_position, player.stats)
	else:
		for c in cards:
			player.stats.discard.add_card(c)
	var picker := enemy.enemy_action_picker
	if picker:
		picker.notify_picker_action_finished()
	Events.enemy_action_completed.emit(enemy)
