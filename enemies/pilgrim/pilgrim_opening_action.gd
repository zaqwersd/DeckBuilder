extends EnemyAction

const PROFANE := preload("res://common_cards/profane.tres")

@export var draw_insert_count := 3
@export var discard_insert_count := 3
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
	var to_draw: Array[Card] = []
	for _i in draw_insert_count:
		to_draw.append(PROFANE.duplicate() as Card)
	var to_discard: Array[Card] = []
	for _i in discard_insert_count:
		to_discard.append(PROFANE.duplicate() as Card)
	var fx: Node = player.get_tree().get_first_node_in_group("battle_card_fx")
	if fx and fx.is_inside_tree() and fx.has_method("animate_multi_insert_split_draw_discard"):
		await fx.animate_multi_insert_split_draw_discard(to_draw, to_discard, player.stats)
	else:
		for c in to_draw:
			player.stats.draw_pile.insert_card_at_random(c)
		for c in to_discard:
			player.stats.discard.insert_card_at_random(c)
	SFXPlayer.play(sound)
	Events.enemy_action_completed.emit(enemy)
