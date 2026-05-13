extends EnemyAction

const TOXIN = preload("res://common_cards/ghost.tres")

@export var damage := 8
## 与攻击并列显示的「侵蚀」意图（塞牌等）；图标可在资源里配置
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
		if erosion_intent.base_text.is_empty():
			erosion_intent.current_text = ""
		else:
			erosion_intent.current_text = erosion_intent.base_text


func perform_action() -> void:
	if not enemy or not target:
		return
	
	var player := target as Player
	if not player:
		return
	
	var tween := create_tween().set_trans(Tween.TRANS_QUINT)
	var start := enemy.global_position
	var end := EnemyAction.attack_lunge_position(start)
	var damage_effect := DamageEffect.new()
	var target_array: Array[Node] = [target]
	var modified_dmg := enemy.modifier_handler.get_modified_value(damage, Modifier.Type.DMG_DEALT)
	
	damage_effect.amount = modified_dmg
	damage_effect.sound = sound
	
	tween.tween_property(enemy, "global_position", end, 0.4)
	tween.tween_callback(damage_effect.execute.bind(target_array))
	tween.tween_callback(_spawn_toxin_into_draw_pile_visual.bind(player))
	tween.tween_interval(0.25)
	tween.tween_property(enemy, "global_position", start, 0.4)
	
	tween.finished.connect(
		func():
			if not is_instance_valid(enemy):
				return
			Events.enemy_action_completed.emit(enemy)
	)


func _spawn_toxin_into_draw_pile_visual(player: Player) -> void:
	var toxin := TOXIN.duplicate()
	var fx: Node = player.get_tree().get_first_node_in_group("battle_card_fx")
	if fx and fx.is_inside_tree() and fx.has_method("animate_insert_into_draw_pile"):
		fx.animate_insert_into_draw_pile(toxin, enemy.global_position, player.stats)
	else:
		player.stats.draw_pile.add_card(toxin)


func update_intent_text() -> void:
	var player := target as Player
	if not player or not enemy:
		return
	
	var modified_dmg := player.modifier_handler.get_modified_value(damage, Modifier.Type.DMG_TAKEN)
	var final_dmg := enemy.modifier_handler.get_modified_value(modified_dmg, Modifier.Type.DMG_DEALT)
	if intent:
		intent.set_attack_segments_display(final_dmg, 1)
