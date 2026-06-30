class_name StatusEffect
extends Effect

var status: Status


func execute(targets: Array[Node]) -> void:
	for target in targets:
		if not target:
			continue
		if not (target is Enemy or target is Player):
			continue
		var to_apply := status
		if target is Player and _is_during_enemy_turn(target):
			to_apply = status.duplicate()
			to_apply.awaits_turn_start = true
		elif target is Enemy and _should_tick_on_player_turn_start_on_enemy(status):
			to_apply = status.duplicate()
			to_apply.type = Status.Type.EVENT_BASED
			to_apply.ticks_on_player_turn_start_on_enemy = true
		target.status_handler.add_status(to_apply)


func _is_during_enemy_turn(target: Node) -> bool:
	var tree := target.get_tree()
	if tree == null:
		return false
	var enemy_handler := tree.get_first_node_in_group("enemy_handler") as EnemyHandler
	if enemy_handler == null:
		return false
	return not enemy_handler.acting_enemies.is_empty()


func _should_tick_on_player_turn_start_on_enemy(status: Status) -> bool:
	return (
		status.can_expire
		and status.stack_type == Status.StackType.DURATION
		and status.polarity == Status.Polarity.NEGATIVE
	)
