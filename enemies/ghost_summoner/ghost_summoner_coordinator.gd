class_name GhostSummonerCoordinator
extends RefCounted

const ACTION_STRIKE5X3 := &"Strike5x3"
const ACTION_HEAL := &"HealSpook"
const ACTION_STRENGTH := &"StrengthSpook"
const ACTION_BLOCK := &"BlockAll"
const ACTION_SUMMON := &"Summon"

const SPOOK_VARIANTS: Array[String] = ["red", "green", "blue"]

static var _force_summon_next_turn := false
static var _initial_spawned := false
static var _spook_prepared := false
static var _summon_order: Array[String] = []
static var _summon_order_index := 0


static func reset_combat() -> void:
	_force_summon_next_turn = false
	_initial_spawned = false
	_spook_prepared = false
	_summon_order = SPOOK_VARIANTS.duplicate()
	_summon_order.shuffle()
	_summon_order_index = 0


## 按本场随机排列的 [r,g,b] 顺序取下一只幽灵；初始与后续复活共用同一循环。
static func take_next_summon_variant() -> String:
	if _summon_order.is_empty():
		_summon_order = SPOOK_VARIANTS.duplicate()
		_summon_order.shuffle()
	var variant := _summon_order[_summon_order_index % _summon_order.size()]
	_summon_order_index += 1
	return variant


static func assign_for_handler(handler: EnemyHandler) -> void:
	if handler == null:
		return
	var summoner := handler.find_ghost_summoner()
	if summoner == null:
		return
	if not _initial_spawned:
		_finalize_initial_spook(handler, summoner)
	for child in handler.get_children():
		if not child is Enemy:
			continue
		var enemy := child as Enemy
		if not handler._is_live_enemy(enemy):
			continue
		if enemy.stats is SpookEnemyStats:
			if enemy.enemy_action_picker is SpookEnemyAI and not _spook_prepared:
				(enemy.enemy_action_picker as SpookEnemyAI).prepare_for_turn(true)
				_spook_prepared = true
			enemy.update_action(false)
	var ai := _get_summoner_ai(summoner)
	if ai == null:
		return
	if _force_summon_next_turn:
		ai.assigned_action_name = ACTION_SUMMON
		summoner.update_action(false)
		return
	var spook := handler.find_live_spook()
	if spook != null and spook.enemy_action_picker is SpookEnemyAI:
		var spook_ai := spook.enemy_action_picker as SpookEnemyAI
		if spook_ai.is_planned_intent2():
			ai.assigned_action_name = ACTION_STRIKE5X3
			summoner.update_action(false)
			return
	var support_actions: Array[StringName] = [ACTION_HEAL, ACTION_STRENGTH, ACTION_BLOCK]
	ai.assigned_action_name = support_actions[RNG.instance.randi_range(0, support_actions.size() - 1)]
	summoner.update_action(false)


static func notify_spook_died(handler: EnemyHandler) -> void:
	if handler == null or handler.find_ghost_summoner() == null:
		return
	_force_summon_next_turn = true
	var summoner := handler.find_ghost_summoner()
	_refresh_summoner_scapeghost(summoner)


static func clear_force_summon() -> void:
	_force_summon_next_turn = false


static func consume_force_summon_on_perform() -> void:
	_force_summon_next_turn = false


static func _finalize_initial_spook(handler: EnemyHandler, summoner: Enemy) -> void:
	var layout_spooks: Array[Enemy] = []
	for child in handler.get_children():
		if child is Enemy and (child as Enemy).stats is SpookEnemyStats:
			layout_spooks.append(child as Enemy)
	var variant := take_next_summon_variant()
	if layout_spooks.is_empty():
		handler.spawn_spook(variant, SpookEnemyStats.INITIAL_HEALTH, SpookEnemyStats.SPOOK_SLOT)
		_initial_spawned = true
		_refresh_summoner_scapeghost(summoner)
		return
	var kept: Enemy = null
	for spook in layout_spooks:
		if SpookEnemyStats.variant_for_stats(spook.stats) == variant:
			kept = spook
			break
	if kept == null:
		kept = layout_spooks[0]
		kept.stats = SpookEnemyStats.stats_for_variant(variant)
	for spook in layout_spooks:
		if spook != kept:
			spook.free()
	SpookEnemyStats.apply_spawn_health(kept.stats, SpookEnemyStats.INITIAL_HEALTH)
	handler.remember_spook_spawn_position(kept.position)
	handler.apply_spook_minion(kept, summoner)
	_initial_spawned = true
	_refresh_summoner_scapeghost(summoner)


static func _get_summoner_ai(summoner: Enemy) -> GhostSummonerEnemyAI:
	if summoner == null or summoner.enemy_action_picker == null:
		return null
	return summoner.enemy_action_picker as GhostSummonerEnemyAI


static func _refresh_summoner_scapeghost(summoner: Enemy) -> void:
	if summoner == null:
		return
	var scapeghost := ScapeghostStatus.get_on_enemy(summoner)
	if scapeghost != null:
		scapeghost._refresh_modifier()
