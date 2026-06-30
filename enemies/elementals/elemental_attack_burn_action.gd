extends EnemyAction

const BURN_CARD := preload("res://common_cards/burn.tres")

@export var damage := 4
@export var burn_intent: Intent


func get_planned_intents() -> Array[Intent]:
	var out: Array[Intent] = []
	if intent:
		out.append(intent)
	if burn_intent:
		out.append(burn_intent)
	return out


func update_planned_intents() -> void:
	if intent:
		intent.set_attack_segments_display(compute_damage_against_player(damage), 1)
	if burn_intent:
		burn_intent.display_number = Intent.NUMBER_HIDDEN
		burn_intent.current_text = "塞入灼伤"


func perform_action() -> void:
	if not enemy or not target:
		return
	var tween := create_tween().set_trans(Tween.TRANS_QUINT)
	var start := EnemyAction.attack_lunge_home(enemy)
	var end := EnemyAction.attack_lunge_position(start)
	var damage_effect := make_final_player_damage_effect(compute_damage_against_player(damage))
	var target_array: Array[Node] = [target]
	tween.tween_property(enemy, "global_position", end, 0.28)
	tween.tween_callback(damage_effect.execute.bind(target_array))
	tween.tween_interval(0.16)
	tween.tween_property(enemy, "global_position", start, 0.28)
	tween.tween_callback(_insert_burn)
	tween.finished.connect(func(): Events.enemy_action_completed.emit(enemy))


func _insert_burn() -> void:
	var ph := get_tree().get_first_node_in_group("player_handler") as PlayerHandler
	if ph == null or ph.character == null:
		return
	ph.character.discard.add_card(BURN_CARD.duplicate(true) as Card)