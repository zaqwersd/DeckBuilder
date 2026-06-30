class_name PilgrimIntentCoordinator
extends RefCounted

const _PILGRIM_STATS_SCRIPT := preload("res://enemies/pilgrim/pilgrim_enemy_stats.gd")

const INTENT_OPENING := 1
const INTENT_STRIKE4X3 := 2
const INTENT_BUFF := 3

const ACTION_OPENING := &"PilgrimOpening"
const ACTION_STRIKE4X3 := &"PilgrimStrike4x3"
const ACTION_BUFF := &"PilgrimBuff"

static var _combat_turn_number: int = 0


static func reset_combat() -> void:
	_combat_turn_number = 0


static func assign_for_handler(handler: EnemyHandler) -> void:
	var ais := _collect_ais(handler)
	if ais.is_empty():
		return
	_combat_turn_number += 1
	for ai in ais:
		if _combat_turn_number == 1:
			ai.assigned_action_name = ACTION_OPENING
			continue
		var last_id: int = ai.get_last_intent_id()
		if last_id == INTENT_STRIKE4X3:
			ai.assigned_action_name = ACTION_BUFF
		else:
			ai.assigned_action_name = ACTION_STRIKE4X3


static func _collect_ais(handler: EnemyHandler) -> Array:
	var ais: Array = []
	for enemy in EnemyHandler.collect_sorted_live_enemies(handler):
		if enemy.stats == null or enemy.stats.get_script() != _PILGRIM_STATS_SCRIPT:
			continue
		if not is_instance_valid(enemy.enemy_action_picker):
			continue
		var ai := enemy.enemy_action_picker
		if ai != null and ai.has_method("get_last_intent_id"):
			ais.append(ai)
	return ais


static func action_name_to_intent_id(action_name: String) -> int:
	match StringName(action_name):
		ACTION_OPENING:
			return INTENT_OPENING
		ACTION_STRIKE4X3:
			return INTENT_STRIKE4X3
		ACTION_BUFF:
			return INTENT_BUFF
	return -1
