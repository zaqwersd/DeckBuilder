class_name ElementalFixedAI
extends EnemyActionPicker

@export var action_name := "Action"

func get_action() -> EnemyAction:
	return get_node(action_name) as EnemyAction