extends EnemyAction

@export var spawn_hp := SpookEnemyStats.RESPAWN_HEALTH


func perform_action() -> void:
	if not enemy:
		return
	var handler := enemy.get_parent() as EnemyHandler
	if handler == null:
		Events.enemy_action_completed.emit(enemy)
		return
	var variant := GhostSummonerCoordinator.take_next_summon_variant()
	handler.spawn_spook(variant, spawn_hp, SpookEnemyStats.SPOOK_SLOT)
	GhostSummonerCoordinator.consume_force_summon_on_perform()
	SFXPlayer.play(sound)
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(enemy):
		Events.enemy_action_completed.emit(enemy)


func update_intent_text() -> void:
	if intent:
		intent.display_number = Intent.NUMBER_HIDDEN
