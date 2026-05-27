class_name BoneShewerIntentCoordinator
extends RefCounted

const INTENT_DEBUFF := 1
const INTENT_STRIKE11 := 2
const INTENT_BUFF5 := 3

const ACTION_DEBUFF := &"BoneShewerDebuff"
const ACTION_STRIKE11 := &"BoneShewerStrike11"
const ACTION_BUFF5 := &"BoneShewerBuff5"

static var _combat_turn_number: int = 0


static func reset_combat() -> void:
	_combat_turn_number = 0


static func assign_for_handler(handler: EnemyHandler) -> void:
	var ais := _collect_ais(handler)
	if ais.is_empty():
		return
	_combat_turn_number += 1
	for ai: BoneShewerAI in ais:
		if _combat_turn_number == 1:
			ai.assigned_action_name = ACTION_DEBUFF
			continue
		var last_id := ai.get_last_intent_id()
		if last_id == INTENT_STRIKE11:
			ai.assigned_action_name = ACTION_BUFF5
		else:
			ai.assigned_action_name = ACTION_STRIKE11


static func _collect_ais(handler: EnemyHandler) -> Array[BoneShewerAI]:
	var ais: Array[BoneShewerAI] = []
	for child in handler.get_children():
		if not child is Enemy:
			continue
		var e := child as Enemy
		if not e.stats is BoneShewerEnemyStats:
			continue
		if not is_instance_valid(e.stats) or e.stats.health <= 0:
			continue
		if not is_instance_valid(e.enemy_action_picker):
			continue
		var ai := e.enemy_action_picker as BoneShewerAI
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
