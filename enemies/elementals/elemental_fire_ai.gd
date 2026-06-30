class_name ElementalFireAI
extends EnemyActionPicker

var _turn := 0

func get_action() -> EnemyAction:
	var action_name := "Attack" if _turn % 2 == 0 else "Burn"
	_turn += 1
	return get_node(action_name) as EnemyAction