extends EnemyAction

const FRAIL := preload("res://statuses/frail.tres")

@export var damage := 3
@export var debuff_intent: Intent


func get_planned_intents() -> Array[Intent]:
	var arr: Array[Intent] = []
	if intent:
		arr.append(intent)
	if debuff_intent:
		arr.append(debuff_intent)
	return arr


func update_planned_intents() -> void:
	if not enemy or not target:
		return
	var final_dmg := compute_damage_against_player(damage)
	if intent:
		intent.set_attack_segments_display(final_dmg, 1)
	if debuff_intent:
		debuff_intent.display_number = Intent.NUMBER_HIDDEN
		if debuff_intent.base_text.is_empty():
			debuff_intent.current_text = "脆弱"
		else:
			debuff_intent.current_text = debuff_intent.base_text


func perform_action() -> void:
	if not enemy or not target:
		return
	
	var tween := create_tween().set_trans(Tween.TRANS_QUINT)
	var start := EnemyAction.attack_lunge_home(enemy)
	var end := EnemyAction.attack_lunge_position(start)
	var per_hit := compute_damage_against_player(damage)
	var damage_effect := make_final_player_damage_effect(per_hit)
	var target_array: Array[Node] = [target]
	
	tween.tween_property(enemy, "global_position", end, 0.4)
	tween.tween_callback(damage_effect.execute.bind(target_array))
	tween.tween_interval(0.25)
	tween.tween_property(enemy, "global_position", start, 0.4)
	tween.tween_callback(_apply_frail.bind(target_array))
	tween.tween_interval(0.15)
	
	tween.finished.connect(
		func():
			if not is_instance_valid(enemy):
				return
			Events.enemy_action_completed.emit(enemy)
	)


func _apply_frail(targets: Array[Node]) -> void:
	var frail := FRAIL.duplicate()
	frail.duration = 1
	var status_effect := StatusEffect.new()
	status_effect.status = frail
	status_effect.execute(targets)
