class_name ElementalDarkAI
extends EnemyActionPicker

var _did_buff := false

func get_action() -> EnemyAction:
	if not _did_buff:
		_did_buff = true
		return get_node("Darkness") as EnemyAction
	return get_node("Attack") as EnemyAction