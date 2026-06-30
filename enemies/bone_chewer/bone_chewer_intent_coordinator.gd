class_name BoneChewerIntentCoordinator
extends RefCounted

const INTENT_DEBUFF := 1
const INTENT_STRIKE11 := 2
const INTENT_BUFF5 := 3

const ACTION_DEBUFF := &"BoneChewerDebuff"
const ACTION_STRIKE11 := &"BoneChewerStrike11"
const ACTION_BUFF5 := &"BoneChewerBuff5"

static var _combat_turn_number: int = 0


static func reset_combat() -> void:
	_combat_turn_number = 0


static func assign_for_handler(handler: EnemyHandler) -> void:
	var ais := _collect_ais(handler)
	if ais.is_empty():
		return
	_combat_turn_number += 1
	for ai: BoneChewerAI in ais:
		if _combat_turn_number == 1:
			ai.assigned_action_name = ACTION_DEBUFF
			continue
		var last_id := ai.get_last_intent_id()
		if last_id == INTENT_STRIKE11:
			ai.assigned_action_name = ACTION_BUFF5
		else:
			ai.assigned_action_name = ACTION_STRIKE11


static func _collect_ais(handler: EnemyHandler) -> Array[BoneChewerAI]:
	var ais: Array[BoneChewerAI] = []
	for enemy in EnemyHandler.collect_sorted_live_enemies(handler):
		if not enemy.stats is BoneChewerEnemyStats:
			continue
		if not is_instance_valid(enemy.enemy_action_picker):
			continue
		var ai := enemy.enemy_action_picker as BoneChewerAI
		if ai:
			ais.append(ai)
	return ais


static func action_name_to_intent_id(action_name: String) -> int:
	match StringName(action_name):
		ACTION_DEBUFF:
			return INTENT_DEBUFF
		ACTION_STRIKE11:
			return INTENT_STRIKE11
		ACTION_BUFF5:
			return INTENT_BUFF5
	return -1
