class_name CrabIntentCoordinator
extends RefCounted

const INTENT_STRIKE7_BLOCK4 := 1
const INTENT_STRIKE4X_TURN := 2
const INTENT_BLOCK15 := 3

const ACTION_STRIKE7_BLOCK4 := &"CrabStrike7Block4"
const ACTION_STRIKE4X_TURN := &"CrabStrike4xTurn"
const ACTION_BLOCK15 := &"CrabBlock15"

const ALL_INTENTS: Array[int] = [INTENT_STRIKE7_BLOCK4, INTENT_STRIKE4X_TURN, INTENT_BLOCK15]

static var _roll_index: int = 0
static var _combat_turn_number: int = 0


static func reset_combat() -> void:
	_roll_index = 0
	_combat_turn_number = 0


static func get_combat_turn_number() -> int:
	return maxi(1, _combat_turn_number)


static func assign_for_handler(handler: EnemyHandler) -> void:
	var ais := _collect_ais(handler)
	if ais.is_empty():
		return
	_combat_turn_number += 1
	var is_first_roll := _roll_index == 0
	for ai: CrabEnemyAI in ais:
		var choices: Array[int] = ALL_INTENTS.duplicate()
		if is_first_roll:
			choices.erase(INTENT_STRIKE4X_TURN)
		var last_id := ai.get_last_intent_id()
		if last_id in choices and choices.size() > 1:
			choices.erase(last_id)
		if choices.is_empty():
			choices = ALL_INTENTS.duplicate()
			if is_first_roll:
				choices.erase(INTENT_STRIKE4X_TURN)
		var pick: int = choices[RNG.instance.randi() % choices.size()]
		ai.assigned_action_name = _intent_to_action_name(pick)
		if pick == INTENT_STRIKE4X_TURN:
			ai.planned_multihit_turn = _combat_turn_number
	_roll_index += 1


static func _collect_ais(handler: EnemyHandler) -> Array[CrabEnemyAI]:
	var ais: Array[CrabEnemyAI] = []
	for child in handler.get_children():
		if not child is Enemy:
			continue
		var e := child as Enemy
		if not e.stats is CrabEnemyStats:
			continue
		if not is_instance_valid(e.stats) or e.stats.health <= 0:
			continue
		if not is_instance_valid(e.enemy_action_picker):
			continue
		var ai := e.enemy_action_picker as CrabEnemyAI
		if ai:
			ais.append(ai)
	return ais


static func _intent_to_action_name(intent_id: int) -> StringName:
	match intent_id:
		INTENT_STRIKE7_BLOCK4:
			return ACTION_STRIKE7_BLOCK4
		INTENT_STRIKE4X_TURN:
			return ACTION_STRIKE4X_TURN
		INTENT_BLOCK15:
			return ACTION_BLOCK15
	return ACTION_BLOCK15


static func action_name_to_intent_id(action_name: String) -> int:
	match StringName(action_name):
		ACTION_STRIKE7_BLOCK4:
			return INTENT_STRIKE7_BLOCK4
		ACTION_STRIKE4X_TURN:
			return INTENT_STRIKE4X_TURN
		ACTION_BLOCK15:
			return INTENT_BLOCK15
	return -1
