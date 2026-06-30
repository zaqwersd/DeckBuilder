extends EnemyAction

const STRENGTH_STATUS := preload("res://statuses/strength.tres")

@export var damage := 2
@export var stacks_per_action := 1
@export var buff_intent: Intent


func get_planned_intents() -> Array[Intent]:
	var arr: Array[Intent] = []
	if intent:
		arr.append(intent)
	if buff_intent:
		arr.append(buff_intent)
	return arr


func update_planned_intents() -> void:
	if not enemy or not target:
		return
	var final_dmg := compute_damage_against_player(damage)
	if intent:
		intent.set_attack_segments_display(final_dmg, 1)
	if buff_intent:
		buff_intent.display_number = Intent.NUMBER_HIDDEN
		if buff_intent.base_text.is_empty():
			buff_intent.current_text = ""
		else:
			buff_intent.current_text = buff_intent.base_text % stacks_per_action


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
	tween.tween_callback(_apply_strength.bind(enemy))
	tween.tween_interval(0.15)

	tween.finished.connect(
		func():
			if not is_instance_valid(enemy):
				return
			Events.enemy_action_completed.emit(enemy)
	)


func _apply_strength(recipient: Enemy) -> void:
	if not is_instance_valid(recipient):
		return
	var status_effect := StatusEffect.new()
	var strength := STRENGTH_STATUS.duplicate()
	strength.stacks = stacks_per_action
	status_effect.status = strength
	status_effect.execute([recipient])
