extends EnemyAction

@export var block_amount := 12
@export var block_intent: Intent


func get_planned_intents() -> Array[Intent]:
	var arr: Array[Intent] = []
	if block_intent:
		arr.append(block_intent)
	return arr


func update_planned_intents() -> void:
	if block_intent:
		block_intent.display_number = block_amount


func perform_action() -> void:
	if not enemy:
		return
	var targets: Array[Node] = [enemy]
	var spook := _find_spook()
	if spook != null:
		targets.append(spook)
	var block_effect := BlockEffect.new()
	block_effect.amount = block_amount
	block_effect.execute(targets)
	await get_tree().create_timer(0.35).timeout
	if is_instance_valid(enemy):
		Events.enemy_action_completed.emit(enemy)


func _find_spook() -> Enemy:
	var handler := enemy.get_parent() as EnemyHandler
	if handler == null:
		return null
	return handler.find_live_spook()
