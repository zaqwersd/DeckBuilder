extends EnemyAction

@export var block := 4


func perform_action() -> void:
	if not enemy:
		return
	var recipient := _find_lowest_hp_little_skelton()
	if recipient == null:
		recipient = enemy
	
	var block_effect := BlockEffect.new()
	block_effect.amount = block
	block_effect.sound = sound
	block_effect.execute([recipient])
	
	get_tree().create_timer(0.6, false).timeout.connect(
		func():
			if not is_instance_valid(enemy):
				return
			Events.enemy_action_completed.emit(enemy)
	)


func _find_lowest_hp_little_skelton() -> Enemy:
	var handler := enemy.get_parent() as EnemyHandler
	if handler == null:
		return null
	var best: Enemy = null
	var best_hp := 999999
	var best_slot := 999
	for child in handler.get_children():
		if not child is Enemy:
			continue
		var skel := child as Enemy
		if not skel.stats is LittleSkeltonEnemyStats:
			continue
		if not is_instance_valid(skel.stats) or skel.stats.health <= 0:
			continue
		var hp := skel.stats.health
		var slot := 999
		if skel.has_meta(EnemyHandler.META_SKELETON_SLOT):
			slot = int(skel.get_meta(EnemyHandler.META_SKELETON_SLOT))
		if hp < best_hp or (hp == best_hp and slot < best_slot):
			best_hp = hp
			best_slot = slot
			best = skel
	return best


func update_intent_text() -> void:
	if intent:
		intent.display_number = block
		intent.current_text = ""
