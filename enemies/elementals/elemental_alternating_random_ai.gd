class_name ElementalAlternatingRandomAI
extends EnemyActionPicker

var _next_name := ""


func _ready() -> void:
	super._ready()
	if not _try_restore_from_snapshot():
		_roll_initial_action()
	call_deferred("_sync_to_snapshot")


func _roll_initial_action() -> void:
	_next_name = "Attack" if RNG.instance.randi() % 2 == 0 else "Other"


func _try_restore_from_snapshot() -> bool:
	if not is_instance_valid(enemy):
		return false
	var state := ElementalAISnapshot.read_ai_state(enemy.name)
	if state.is_empty() or state.get("kind") != ElementalAISnapshot.KIND_ALT_RANDOM:
		return false
	var name := String(state.get("next_name", ""))
	if name != "Attack" and name != "Other":
		return false
	_next_name = name
	return true


func write_state_to_snapshot() -> void:
	if not is_instance_valid(enemy) or _next_name.is_empty():
		return
	ElementalAISnapshot.write_ai_state(enemy.name, {
		"kind": ElementalAISnapshot.KIND_ALT_RANDOM,
		"next_name": _next_name,
	})


func _sync_to_snapshot() -> void:
	write_state_to_snapshot()


func get_action() -> EnemyAction:
	if _next_name.is_empty():
		if not _try_restore_from_snapshot():
			_roll_initial_action()
	var action := get_node(_next_name) as EnemyAction
	_next_name = "Other" if _next_name == "Attack" else "Attack"
	return action
