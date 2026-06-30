class_name ElementalIceAI
extends EnemyActionPicker

var _sequence: Array[String] = []
var _index := 0


func _ready() -> void:
	super._ready()
	if not _try_restore_from_snapshot():
		_build_sequence()
	call_deferred("_sync_to_snapshot")


func _build_sequence() -> void:
	_sequence = ["Attack", "Debuff", "Block"]
	RNG.array_shuffle(_sequence)
	_index = 0


func _try_restore_from_snapshot() -> bool:
	if not is_instance_valid(enemy):
		return false
	var state := ElementalAISnapshot.read_ai_state(enemy.name)
	if state.is_empty() or state.get("kind") != ElementalAISnapshot.KIND_ICE:
		return false
	var raw_seq: Variant = state.get("sequence")
	if typeof(raw_seq) != TYPE_ARRAY:
		return false
	_sequence.clear()
	for entry: Variant in raw_seq as Array:
		_sequence.append(String(entry))
	if _sequence.size() != 3:
		_sequence.clear()
		return false
	_index = 0
	return true


func write_state_to_snapshot() -> void:
	if not is_instance_valid(enemy) or _sequence.size() != 3:
		return
	ElementalAISnapshot.write_ai_state(enemy.name, {
		"kind": ElementalAISnapshot.KIND_ICE,
		"sequence": _sequence.duplicate(),
	})


func _sync_to_snapshot() -> void:
	write_state_to_snapshot()


func get_action() -> EnemyAction:
	if _sequence.is_empty():
		if not _try_restore_from_snapshot():
			_build_sequence()
	var name := _sequence[_index % _sequence.size()]
	_index += 1
	return get_node(name) as EnemyAction
