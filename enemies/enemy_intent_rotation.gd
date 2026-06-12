class_name EnemyIntentRotation
extends RefCounted

## 同一意图若已连续缺席该回合数，本回合必须从候选中强制出现。
const MAX_TURNS_WITHOUT_INTENT := 4


static func filter_no_consecutive_repeat(
	candidates: Array,
	last_id,
	get_id: Callable,
) -> Array:
	if last_id == null or (last_id is int and last_id < 0) or (last_id is String and last_id.is_empty()):
		return candidates.duplicate()
	var filtered: Array = []
	for item in candidates:
		if get_id.call(item) == last_id:
			continue
		filtered.append(item)
	if filtered.is_empty():
		return candidates.duplicate()
	return filtered


static func filter_must_reappear(
	candidates: Array,
	current_turn: int,
	get_last_used_turn: Callable,
	get_id: Callable,
) -> Array:
	var forced: Array = []
	for item in candidates:
		var id = get_id.call(item)
		var last_turn: int = int(get_last_used_turn.call(id))
		if current_turn - last_turn >= MAX_TURNS_WITHOUT_INTENT:
			forced.append(item)
	if forced.is_empty():
		return candidates
	var intersection: Array = []
	for item in forced:
		if item in candidates:
			intersection.append(item)
	if intersection.is_empty():
		return candidates
	return intersection
