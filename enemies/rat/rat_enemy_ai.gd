class_name RatEnemyAI
extends EnemyActionPicker

const ACTION_NAMES: Array[StringName] = [
	&"RatStrike5Weak",
	&"RatStrike13",
	&"RatStrike9",
]
const ACTION_WEIGHTS: Array[int] = [2, 1, 1]


func get_action() -> EnemyAction:
	var idx := _pick_weighted_action_index()
	var path := NodePath(String(ACTION_NAMES[idx]))
	if not has_node(path):
		return null
	return get_node(path) as EnemyAction


func _pick_weighted_action_index() -> int:
	var total := 0
	for w in ACTION_WEIGHTS:
		total += w
	var roll := RNG.instance.randi_range(0, total - 1)
	var acc := 0
	for i in ACTION_WEIGHTS.size():
		acc += ACTION_WEIGHTS[i]
		if roll < acc:
			return i
	return ACTION_WEIGHTS.size() - 1
