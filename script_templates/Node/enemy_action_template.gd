# meta-name: EnemyAction
# meta-description: An action which can be performed by an enemy during its turn.
extends EnemyAction


func perform_action() -> void:
	if not enemy or not target:
		return
	
	var tween := create_tween().set_trans(Tween.TRANS_QUINT)
	var start := enemy.global_position
	var end := EnemyAction.attack_lunge_position(start)
	
	SFXPlayer.play(sound)

	Events.enemy_action_completed.emit(enemy)


# If the enemy has dynamic intent text you can override the base behaviour here
# e.g. for attack actions, the Player's DMG TAKEN modifier modifies the resulting damage number.
func update_intent_text() -> void:
	var player := target as Player
	if not player or not enemy:
		return
	
	var modified_dmg := player.modifier_handler.get_modified_value(6, Modifier.Type.DMG_TAKEN)
	var per_hit := enemy.modifier_handler.get_modified_value(modified_dmg, Modifier.Type.DMG_DEALT)
	if intent:
		intent.set_attack_segments_display(per_hit, 1)
