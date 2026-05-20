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
		if target is Player and _should_show_icon_before_turn_start(target):
			to_apply = status.duplicate()
			to_apply.awaits_turn_start = true
		target.status_handler.add_status(to_apply)


func _should_show_icon_before_turn_start(player: Player) -> bool:
	var tree := player.get_tree()
	if tree == null:
		return false
	var enemy_handler := tree.get_first_node_in_group("enemy_handler") as EnemyHandler
	if enemy_handler == null:
		return false
	return not enemy_handler.acting_enemies.is_empty()
