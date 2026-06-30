extends EnemyAction

const FRAIL := preload("res://statuses/frail.tres")

@export var damage := 18
@export var debuff_intent: Intent


func get_planned_intents() -> Array[Intent]:
	var arr: Array[Intent] = []
	if intent:
		arr.append(intent)
	if debuff_intent:
		arr.append(debuff_intent)
	return arr


func update_planned_intents() -> void:
	var per_hit := damage
	if enemy and target:
		per_hit = compute_damage_against_player(damage)
	if intent:
		intent.set_attack_segments_display(per_hit, 1)
	if debuff_intent:
		debuff_intent.display_number = Intent.NUMBER_HIDDEN
		debuff_intent.current_text = "脆弱"


func perform_action() -> void:
	if not enemy or not target:
		return
	_perform_strike_and_debuff(compute_damage_against_player(damage), _apply_frail)


func _perform_strike_and_debuff(per_hit: int, debuff_fn: Callable) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_QUINT)
	var start := EnemyAction.attack_lunge_home(enemy)
	var end := EnemyAction.attack_lunge_position(start)
	var damage_effect := make_final_player_damage_effect(per_hit)
	var target_array: Array[Node] = [target]
	tween.tween_property(enemy, "global_position", end, 0.4)
	tween.tween_callback(damage_effect.execute.bind(target_array))
	tween.tween_interval(0.25)
	tween.tween_property(enemy, "global_position", start, 0.4)
	tween.tween_callback(debuff_fn.bind(target_array))
	tween.tween_interval(0.15)
	tween.finished.connect(_emit_completed)


func _apply_frail(targets: Array[Node]) -> void:
	var frail := FRAIL.duplicate()
	frail.duration = 1
	var status_effect := StatusEffect.new()
	status_effect.status = frail
	status_effect.execute(targets)


func _emit_completed() -> void:
	if not is_instance_valid(enemy):
		return
	Events.enemy_action_completed.emit(enemy)
