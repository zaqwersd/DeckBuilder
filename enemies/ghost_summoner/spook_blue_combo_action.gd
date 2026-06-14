extends EnemyAction

@export var damage := 6
@export var armor_stacks := 3
@export var secondary_intent: Intent


func get_planned_intents() -> Array[Intent]:
	var arr: Array[Intent] = []
	if intent:
		arr.append(intent)
	if secondary_intent:
		arr.append(secondary_intent)
	return arr


func perform_action() -> void:
	if not enemy or not target:
		return
	var per_hit := compute_damage_against_player(damage)
	var tween := create_tween().set_trans(Tween.TRANS_QUINT)
	var start := enemy.global_position
	var end := EnemyAction.attack_lunge_position(start)
	var damage_effect := make_final_player_damage_effect(per_hit)
	var target_array: Array[Node] = [target]
	tween.tween_property(enemy, "global_position", end, 0.4)
	tween.tween_callback(damage_effect.execute.bind(target_array))
	tween.tween_interval(0.25)
	tween.tween_property(enemy, "global_position", start, 0.4)
	tween.tween_callback(_apply_layered_armor)
	tween.tween_interval(0.15)
	tween.finished.connect(_emit_completed)


func update_planned_intents() -> void:
	var per_hit := damage
	if enemy and target:
		per_hit = compute_damage_against_player(damage)
	if intent:
		intent.set_attack_segments_display(per_hit, 1)
	if secondary_intent:
		secondary_intent.display_number = Intent.NUMBER_HIDDEN


func _apply_layered_armor() -> void:
	var summoner := _find_summoner()
	if summoner == null:
		return
	LayeredArmorStatus.add_stacks_to(summoner, armor_stacks)


func _find_summoner() -> Enemy:
	var handler := enemy.get_parent() as EnemyHandler
	if handler == null:
		return null
	return handler.find_ghost_summoner()


func _emit_completed() -> void:
	if not is_instance_valid(enemy):
		return
	Events.enemy_action_completed.emit(enemy)
