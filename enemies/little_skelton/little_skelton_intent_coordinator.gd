class_name LittleSkeltonIntentCoordinator
extends RefCounted

const INTENT_STRIKE4 := 1
const INTENT_BUFF2 := 2
const INTENT_SHIELD := 3
const INTENT_STRIKE3_FRAIL := 4

const ACTION_STRIKE4 := &"LittleSkeltonStrike4"
const ACTION_BUFF2 := &"LittleSkeltonBuff2"
const ACTION_SHIELD := &"LittleSkeltonShieldLowest"
const ACTION_STRIKE3_FRAIL := &"LittleSkeltonStrike3Frail"

const ALL_INTENTS: Array[int] = [INTENT_STRIKE4, INTENT_BUFF2, INTENT_SHIELD, INTENT_STRIKE3_FRAIL]
const ATTACK_INTENTS: Array[int] = [INTENT_STRIKE4, INTENT_STRIKE3_FRAIL]

static var _roll_index: int = 0

class AssignmentState:
	var by_ai: Dictionary = {}
	var intent4_used: bool = false
	var want_intent_4: bool = false


static func reset_combat() -> void:
	_roll_index = 0


static func assign_for_handler(handler: EnemyHandler) -> void:
	var ais := _collect_ais(handler)
	if ais.is_empty():
		return
	
	var result: Dictionary = {}
	if _roll_index == 0 and ais.size() >= 4:
		result = _assign_first_turn_four(ais)
	elif not _solve_with_backtrack(ais, false, result):
		if not _solve_with_backtrack(ais, true, result):
			_assign_fallback(ais, result)
	
	for ai: LittleSkeltonAI in ais:
		var intent_id: int = int(result.get(ai, INTENT_BUFF2))
		ai.assigned_action_name = _intent_to_action_name(intent_id)
		if ai.must_attack_next_turn:
			ai.must_attack_next_turn = false
	
	_roll_index += 1


static func _collect_ais(handler: EnemyHandler) -> Array[LittleSkeltonAI]:
	var ais: Array[LittleSkeltonAI] = []
	for child in handler.get_children():
		if not child is Enemy:
			continue
		var e := child as Enemy
		if not e.stats is LittleSkeltonEnemyStats:
			continue
		if not is_instance_valid(e.stats) or e.stats.health <= 0:
			continue
		if not is_instance_valid(e.enemy_action_picker):
			continue
		var ai := e.enemy_action_picker as LittleSkeltonAI
		if ai:
			ais.append(ai)
	return ais


## 开局 4 只（`battles/little_skelton_4.tscn`）：固定 1 打 5 + 1 打 3 脆弱，另两只各随机强化或护盾。
static func _assign_first_turn_four(ais: Array[LittleSkeltonAI]) -> Dictionary:
	var shuffled := ais.duplicate()
	RNG.array_shuffle(shuffled)
	var intents: Array[int] = [
		INTENT_STRIKE4,
		INTENT_STRIKE3_FRAIL,
		INTENT_BUFF2 if RNG.instance.randi() % 2 == 0 else INTENT_SHIELD,
		INTENT_BUFF2 if RNG.instance.randi() % 2 == 0 else INTENT_SHIELD,
	]
	var result: Dictionary = {}
	for i in mini(shuffled.size(), intents.size()):
		result[shuffled[i]] = intents[i]
	for i in range(intents.size(), shuffled.size()):
		result[shuffled[i]] = INTENT_BUFF2
	return result


static func _solve_with_backtrack(
	ais: Array[LittleSkeltonAI],
	allow_repeat: bool,
	out_result: Dictionary
) -> bool:
	var state := AssignmentState.new()
	state.want_intent_4 = RNG.instance.randf() < 0.5
	var order := _build_priority_order(ais)
	out_result.clear()
	if _assign_index(0, order, state, allow_repeat, out_result):
		return true
	return false


static func _build_priority_order(ais: Array[LittleSkeltonAI]) -> Array[LittleSkeltonAI]:
	var must: Array[LittleSkeltonAI] = []
	var rest: Array[LittleSkeltonAI] = []
	for ai in ais:
		if ai.must_attack_next_turn:
			must.append(ai)
		else:
			rest.append(ai)
	must.sort_custom(_compare_ai_slot)
	rest.sort_custom(_compare_ai_slot)
	RNG.array_shuffle(rest)
	return must + rest


static func _compare_ai_slot(a: LittleSkeltonAI, b: LittleSkeltonAI) -> bool:
	return _ai_slot_key(a) < _ai_slot_key(b)


static func _ai_slot_key(ai: LittleSkeltonAI) -> int:
	if not is_instance_valid(ai.enemy):
		return 999
	if ai.enemy.has_meta(EnemyHandler.META_SKELETON_SLOT):
		return int(ai.enemy.get_meta(EnemyHandler.META_SKELETON_SLOT))
	return int(ai.enemy.position.x)


static func _assign_index(
	index: int,
	order: Array[LittleSkeltonAI],
	state: AssignmentState,
	allow_repeat: bool,
	out_result: Dictionary
) -> bool:
	if index >= order.size():
		return true
	
	var ai: LittleSkeltonAI = order[index]
	var choices := _allowed(ai, state, allow_repeat)
	if choices.is_empty():
		return false
	
	RNG.array_shuffle(choices)
	for intent_id in choices:
		var next := _apply_intent(state, intent_id)
		out_result[ai] = intent_id
		if _assign_index(index + 1, order, next, allow_repeat, out_result):
			return true
		out_result.erase(ai)
	
	return false


static func _allowed(ai: LittleSkeltonAI, state: AssignmentState, allow_repeat: bool) -> Array[int]:
	var choices: Array[int] = []
	for id in ALL_INTENTS:
		if not allow_repeat and ai.get_last_intent_id() == id:
			continue
		if id == INTENT_STRIKE3_FRAIL:
			if not state.want_intent_4 or state.intent4_used:
				continue
		if ai.must_attack_next_turn and id not in ATTACK_INTENTS:
			continue
		choices.append(id)
	return choices


static func _apply_intent(state: AssignmentState, intent_id: int) -> AssignmentState:
	var next := AssignmentState.new()
	next.by_ai = state.by_ai.duplicate()
	next.intent4_used = state.intent4_used
	next.want_intent_4 = state.want_intent_4
	if intent_id == INTENT_STRIKE3_FRAIL:
		next.intent4_used = true
	return next


static func _intent_to_action_name(intent_id: int) -> StringName:
	match intent_id:
		INTENT_STRIKE4:
			return ACTION_STRIKE4
		INTENT_BUFF2:
			return ACTION_BUFF2
		INTENT_SHIELD:
			return ACTION_SHIELD
		INTENT_STRIKE3_FRAIL:
			return ACTION_STRIKE3_FRAIL
	return ACTION_BUFF2


## 回溯仍无解时：must_attack 必分配打人意图；其余照常随机（无同时打人数量上限）。
static func _assign_fallback(ais: Array[LittleSkeltonAI], out_result: Dictionary) -> void:
	out_result.clear()
	var want_4: bool = RNG.instance.randf() < 0.5
	var intent4_used := false
	var must: Array[LittleSkeltonAI] = []
	var rest: Array[LittleSkeltonAI] = []
	for ai in ais:
		if ai.must_attack_next_turn:
			must.append(ai)
		else:
			rest.append(ai)
	must.sort_custom(_compare_ai_slot)
	rest.sort_custom(_compare_ai_slot)
	for ai in must:
		var id := _pick_fallback_attack(ai, want_4, intent4_used)
		if id not in ATTACK_INTENTS:
			id = _force_must_attack_intent(ai, want_4, intent4_used)
		if id == INTENT_STRIKE3_FRAIL:
			intent4_used = true
		out_result[ai] = id
	for ai in rest:
		var choices: Array[int] = [INTENT_BUFF2, INTENT_SHIELD]
		if want_4 and not intent4_used and ai.get_last_intent_id() != INTENT_STRIKE3_FRAIL:
			choices.append(INTENT_STRIKE3_FRAIL)
		if ai.get_last_intent_id() != INTENT_STRIKE4:
			choices.append(INTENT_STRIKE4)
		choices = choices.filter(func(c: int) -> bool: return c != ai.get_last_intent_id())
		if choices.is_empty():
			choices = [INTENT_BUFF2, INTENT_SHIELD]
		var pick: int = choices[RNG.instance.randi() % choices.size()]
		if pick == INTENT_STRIKE3_FRAIL:
			intent4_used = true
		out_result[ai] = pick


static func _pick_fallback_attack(
	ai: LittleSkeltonAI,
	want_4: bool,
	intent4_used: bool
) -> int:
	if want_4 and not intent4_used and ai.get_last_intent_id() != INTENT_STRIKE3_FRAIL:
		return INTENT_STRIKE3_FRAIL
	if ai.get_last_intent_id() != INTENT_STRIKE4:
		return INTENT_STRIKE4
	if want_4 and not intent4_used:
		return INTENT_STRIKE3_FRAIL
	return INTENT_BUFF2


## must_attack 兜底：允许打破不连发，仍须为打人意图。
static func _force_must_attack_intent(
	ai: LittleSkeltonAI,
	want_4: bool,
	intent4_used: bool
) -> int:
	if want_4 and not intent4_used:
		return INTENT_STRIKE3_FRAIL
	return INTENT_STRIKE4


static func action_name_to_intent_id(action_name: String) -> int:
	match StringName(action_name):
		ACTION_STRIKE4:
			return INTENT_STRIKE4
		ACTION_BUFF2:
			return INTENT_BUFF2
		ACTION_SHIELD:
			return INTENT_SHIELD
		ACTION_STRIKE3_FRAIL:
			return INTENT_STRIKE3_FRAIL
		&"LittleSkeltonStrike5":
			return INTENT_STRIKE4
		&"LittleSkeltonBuff3":
			return INTENT_BUFF2
	return -1
