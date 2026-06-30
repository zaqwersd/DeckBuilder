extends EnemyAction

const STRENGTH := preload("res://statuses/strength.tres")

@export var strike_intent: Intent
@export var str_intent: Intent
@export var damage := 36
@export var strength_stacks := 10


func get_planned_intents() -> Array[Intent]:
	var arr: Array[Intent] = []
	if strike_intent:
		arr.append(strike_intent)
	if str_intent:
		arr.append(str_intent)
	return arr


func update_planned_intents() -> void:
	if not enemy or not target:
		return
	var player := target as Player
	if not player:
		return
	var final_dmg := compute_damage_against_player(damage)
	if strike_intent:
		strike_intent.set_attack_segments_display(final_dmg, 1)
	if str_intent:
		str_intent.display_number = Intent.NUMBER_HIDDEN
		str_intent.current_text = ""


func perform_action() -> void:
	if not enemy or not target:
		return
	var player := target as Player
	if not player:
		return
	var final_dmg := compute_damage_against_player(damage)
	var tween := create_tween().set_trans(Tween.TRANS_QUINT)
	var start := EnemyAction.attack_lunge_home(enemy)
	var end := EnemyAction.attack_lunge_position(start)
	var dmg_eff := make_final_player_damage_effect(final_dmg)
	var arr: Array[Node] = [target]
	tween.tween_property(enemy, "global_position", end, 0.42)
	tween.tween_callback(dmg_eff.execute.bind(arr))
	tween.tween_property(enemy, "global_position", start, 0.38)
	tween.tween_callback(_apply_strength)
	tween.tween_interval(0.22)
	tween.finished.connect(
		func():
			if not is_instance_valid(enemy):
				return
			Events.enemy_action_completed.emit(enemy)
	)


func _apply_strength() -> void:
	if not is_instance_valid(enemy):
		return
	var se_str := StatusEffect.new()
	var st := STRENGTH.duplicate()
	st.stacks = strength_stacks
	se_str.status = st
	se_str.execute([enemy])
