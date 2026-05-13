extends EnemyAction

const HAUNTED := preload("res://statuses/haunted.tres")

@export var strike_intent: Intent
@export var debuff_intent: Intent
@export var damage := 20
@export var haunted_stacks := 2


func get_planned_intents() -> Array[Intent]:
	var arr: Array[Intent] = []
	if strike_intent:
		arr.append(strike_intent)
	if debuff_intent:
		arr.append(debuff_intent)
	return arr


func update_planned_intents() -> void:
	var player := target as Player
	if not player or not enemy:
		return
	var modified := player.modifier_handler.get_modified_value(damage, Modifier.Type.DMG_TAKEN)
	var final_dmg := enemy.modifier_handler.get_modified_value(modified, Modifier.Type.DMG_DEALT)
	if strike_intent:
		strike_intent.set_attack_segments_display(final_dmg, 1)
	if debuff_intent:
		debuff_intent.display_number = Intent.NUMBER_HIDDEN
		debuff_intent.current_text = ""


func perform_action() -> void:
	if not enemy or not target:
		return
	var player := target as Player
	if not player:
		return
	var modified := player.modifier_handler.get_modified_value(damage, Modifier.Type.DMG_TAKEN)
	var final_dmg := enemy.modifier_handler.get_modified_value(modified, Modifier.Type.DMG_DEALT)
	var tween := create_tween().set_trans(Tween.TRANS_QUINT)
	var start := enemy.global_position
	var end := EnemyAction.attack_lunge_position(start)
	var dmg_eff := DamageEffect.new()
	dmg_eff.amount = final_dmg
	dmg_eff.sound = sound
	var arr: Array[Node] = [target]
	tween.tween_property(enemy, "global_position", end, 0.42)
	tween.tween_callback(dmg_eff.execute.bind(arr))
	tween.tween_property(enemy, "global_position", start, 0.38)
	tween.tween_callback(_apply_haunted.bind(player))
	tween.tween_interval(0.22)
	tween.finished.connect(
		func():
			if not is_instance_valid(enemy):
				return
			var p := enemy.enemy_action_picker
			if p:
				p.notify_picker_action_finished()
			Events.enemy_action_completed.emit(enemy)
	)


func _apply_haunted(player: Player) -> void:
	var se := StatusEffect.new()
	var h := HAUNTED.duplicate()
	h.stacks = haunted_stacks
	se.status = h
	se.execute([player])
