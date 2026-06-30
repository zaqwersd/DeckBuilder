class_name EnemyHandler
extends Node2D

const ENEMY_SCENE := preload("res://scenes/enemy/enemy.tscn")
const LITTLE_SKELTON_STATS := preload("res://enemies/little_skelton/little_skelton_enemy.tres")
const MINION_STATUS := preload("res://statuses/minion.tres")
const PilgrimIntentCoordinator := preload("res://enemies/pilgrim/pilgrim_intent_coordinator.gd")

const META_SKELETON_SLOT := &"skeleton_slot"
const META_SPOOK_SLOT := &"spook_slot"

## 按 stats.enemy_scene_path 实例化敌人；无配置时回退通用 enemy.tscn。
static func instantiate_enemy(stats: EnemyStats) -> Enemy:
	var scene := ENEMY_SCENE
	if stats != null:
		var custom := stats.get_enemy_scene()
		if custom != null:
			scene = custom
	return scene.instantiate() as Enemy

var acting_enemies: Array[Enemy] = []
## 小骷髅等遭遇：槽位编号 1~5 → 布局局部坐标
var slot_positions: Dictionary = {}
## 幽灵召唤师：本场战斗幽灵登场/复活共用的位置（取自布局里初始幽灵）
var _spook_spawn_position: Vector2
var _has_spook_spawn_position := false
## 玩家回合开始：状态结算完成前隐藏意图，禁止刷新。
var _intent_reveal_pending := false
## 回合开始刚显示意图后，跳过至抽牌完成前的多余刷新（避免 UI 重建闪变）。
var _turn_start_intent_refresh_locked := false
## 力量/易伤等状态同步时，意图刷新会再次触发同步；防止递归栈溢出。
var _player_combat_intent_refresh_depth := 0


func _ready() -> void:
	Events.enemy_died.connect(_on_enemy_died)
	Events.enemy_action_completed.connect(_on_enemy_action_completed)
	Events.player_hand_drawn.connect(_on_player_hand_drawn)
	if not Events.player_combat_stat_context_changed.is_connected(_on_player_combat_stat_context_changed):
		Events.player_combat_stat_context_changed.connect(_on_player_combat_stat_context_changed)
	if not Events.player_turn_intent_context_ready.is_connected(_on_player_turn_intent_context_ready):
		Events.player_turn_intent_context_ready.connect(_on_player_turn_intent_context_ready)
	if not Events.player_drew_cards.is_connected(SinsStatus._on_player_drew_cards):
		Events.player_drew_cards.connect(SinsStatus._on_player_drew_cards)


func is_intent_reveal_pending() -> bool:
	return _intent_reveal_pending


## 场景布局敌人：直接复用战斗布局里的实例（保留 tscn override）；其余仍从 enemy_scene_path 实例化。
func _spawn_enemy_from_layout_template(template: Enemy) -> Enemy:
	var stats_res := template.stats as EnemyStats
	if stats_res != null and stats_res.uses_scene_ui_layout:
		var parent := template.get_parent()
		if parent != null:
			parent.remove_child(template)
		return template
	if stats_res != null:
		var enemy := instantiate_enemy(stats_res)
		enemy.position = template.position
		template.queue_free()
		return enemy
	var fallback := template.duplicate() as Enemy
	fallback.position = template.position
	template.queue_free()
	return fallback


func setup_enemies(battle_stats: BattleStats) -> void:
	if not battle_stats:
		return
	
	SinsStatus.reset_combat()
	
	slot_positions.clear()
	_has_spook_spawn_position = false
	for enemy: Enemy in get_children():
		enemy.free()
	
	var all_new_enemies := battle_stats.enemies.instantiate()
	
	for layout_child: Node in all_new_enemies.get_children():
		if layout_child.name.begins_with("Slot"):
			var slot_key := layout_child.name.trim_prefix("Slot")
			if slot_key.is_valid_int():
				slot_positions[int(slot_key)] = layout_child.position
			continue
		var template := layout_child as Enemy
		if template == null:
			continue
		var new_enemy_child := _spawn_enemy_from_layout_template(template)
		if not is_instance_valid(new_enemy_child):
			continue
		if new_enemy_child.get_parent() != self:
			add_child(new_enemy_child)
		if is_instance_valid(new_enemy_child.status_handler):
			new_enemy_child.status_handler.statuses_applied.connect(
				_on_enemy_statuses_applied.bind(new_enemy_child)
			)
		if is_instance_valid(template.stats):
			new_enemy_child.stats = template.stats
		new_enemy_child.call_deferred("_apply_battle_spawn_visuals")
		if new_enemy_child._uses_scene_ui_layout():
			new_enemy_child.call_deferred("sync_scene_layout_ui")
		if template.has_meta(META_SKELETON_SLOT):
			var slot: int = int(template.get_meta(META_SKELETON_SLOT))
			new_enemy_child.set_meta(META_SKELETON_SLOT, slot)
			if slot_positions.has(slot):
				new_enemy_child.position = slot_positions[slot]
			if new_enemy_child.stats is LittleSkeltonEnemyStats:
				LittleSkeltonEnemyStats.apply_initial_health_for_slot(new_enemy_child.stats, slot)
	
	all_new_enemies.free()
	LittleSkeltonIntentCoordinator.reset_combat()
	BoneChewerIntentCoordinator.reset_combat()
	PilgrimIntentCoordinator.reset_combat()
	GhostSummonerCoordinator.reset_combat()


func reset_enemy_actions() -> void:
	_intent_reveal_pending = true
	_turn_start_intent_refresh_locked = false
	_ensure_enemy_action_pickers_ready()
	LittleSkeltonIntentCoordinator.assign_for_handler(self)
	BoneChewerIntentCoordinator.assign_for_handler(self)
	PilgrimIntentCoordinator.assign_for_handler(self)
	GhostSummonerCoordinator.assign_for_handler(self)
	var enemies: Array[Enemy] = []
	for child in get_children():
		if not _is_live_enemy(child):
			continue
		var enemy := child as Enemy
		enemies.append(enemy)
		enemy.clear_intent_display()
	for enemy in enemies:
		enemy.update_action(false)


func _ensure_enemy_action_pickers_ready() -> void:
	for child in get_children():
		if not child is Enemy:
			continue
		var enemy := child as Enemy
		if not is_instance_valid(enemy.stats):
			continue
		if enemy.enemy_action_picker == null:
			enemy.setup_ai()


func reveal_all_enemy_intents() -> void:
	for child in get_children():
		if not _is_live_enemy(child):
			continue
		var enemy := child as Enemy
		if enemy.current_action == null:
			enemy.update_action(false)
		enemy.update_intent()


func _is_live_enemy(node: Node) -> bool:
	if not node is Enemy or not is_instance_valid(node):
		return false
	var enemy := node as Enemy
	if not enemy.is_inside_tree():
		return false
	if not is_instance_valid(enemy.stats) or enemy.stats.health <= 0:
		return false
	return true


func _on_player_turn_intent_context_ready() -> void:
	if not _intent_reveal_pending:
		return
	_intent_reveal_pending = false
	_turn_start_intent_refresh_locked = true
	reveal_all_enemy_intents()


func start_turn() -> void:
	if get_child_count() == 0:
		push_error("EnemyHandler.start_turn: 场上没有敌人。")
		return
	
	HardShellStatus.expire_all_in_tree(get_tree())
	
	var enemies: Array[Enemy] = []
	for child in get_children():
		if not _is_live_enemy(child):
			continue
		enemies.append(child as Enemy)
	enemies.sort_custom(_compare_enemy_turn_order)
	acting_enemies.assign(enemies)
	
	_start_next_enemy_turn()


## 行动顺序：槽位 1→5（左→右）；无槽位则按 position.x。
func _compare_enemy_turn_order(a: Enemy, b: Enemy) -> bool:
	return _enemy_turn_order_key(a) < _enemy_turn_order_key(b)


func _enemy_turn_order_key(enemy: Enemy) -> int:
	if enemy.has_meta(META_SKELETON_SLOT):
		return int(enemy.get_meta(META_SKELETON_SLOT))
	return int(enemy.position.x)


## 按行动顺序稳定收集存活敌人（避免 get_children 顺序影响 RNG）。
static func collect_sorted_live_enemies(handler: EnemyHandler) -> Array[Enemy]:
	var out: Array[Enemy] = []
	if handler == null:
		return out
	for child in handler.get_children():
		if not child is Enemy:
			continue
		var enemy := child as Enemy
		if not handler._is_live_enemy(enemy):
			continue
		out.append(enemy)
	out.sort_custom(EnemyTargeting.compare_enemies_stable)
	return out


func count_live_spooks() -> int:
	var n := 0
	for child in get_children():
		if not _is_live_enemy(child):
			continue
		if (child as Enemy).stats is SpookEnemyStats:
			n += 1
	return n


func find_live_spook() -> Enemy:
	for child in get_children():
		if not _is_live_enemy(child):
			continue
		var enemy := child as Enemy
		if enemy.stats is SpookEnemyStats:
			return enemy
	return null


func find_ghost_summoner() -> Enemy:
	for child in get_children():
		if not _is_live_enemy(child):
			continue
		var enemy := child as Enemy
		if enemy.stats is GhostSummonerEnemyStats:
			return enemy
	return null


func remember_spook_spawn_position(pos: Vector2) -> void:
	_spook_spawn_position = pos
	_has_spook_spawn_position = true


func get_spook_spawn_position(slot: int) -> Vector2:
	if _has_spook_spawn_position:
		return _spook_spawn_position
	if slot_positions.has(slot):
		return slot_positions[slot]
	return Vector2.ZERO


func spawn_spook(variant: String, max_hp: int, slot: int = SpookEnemyStats.SPOOK_SLOT) -> Enemy:
	if count_live_spooks() >= 1:
		return null
	if not _has_spook_spawn_position and not slot_positions.has(slot):
		return null
	var spawn_pos := get_spook_spawn_position(slot)
	var stats: EnemyStats = _spook_stats_for_variant(variant)
	if stats == null:
		return null
	var new_enemy := instantiate_enemy(stats)
	add_child(new_enemy)
	new_enemy.stats = stats
	new_enemy.call_deferred("_apply_battle_spawn_visuals")
	SpookEnemyStats.apply_spawn_health(new_enemy.stats, max_hp)
	new_enemy.position = spawn_pos
	if not _has_spook_spawn_position:
		remember_spook_spawn_position(spawn_pos)
	new_enemy.set_meta(META_SPOOK_SLOT, slot)
	new_enemy.status_handler.statuses_applied.connect(_on_enemy_statuses_applied.bind(new_enemy))
	new_enemy.setup_ai()
	new_enemy.clear_intent_display()
	if new_enemy.enemy_action_picker is SpookEnemyAI:
		(new_enemy.enemy_action_picker as SpookEnemyAI).prepare_for_turn(true)
	var summoner := find_ghost_summoner()
	if summoner != null:
		apply_spook_minion(new_enemy, summoner)
		var scapeghost := ScapeghostStatus.get_on_enemy(summoner)
		if scapeghost != null:
			scapeghost._refresh_modifier(true)
	return new_enemy


func apply_spook_minion(spook: Enemy, summoner: Enemy) -> void:
	if spook == null or summoner == null or spook.status_handler == null:
		return
	if spook.status_handler.get_status_by_id("minion") != null:
		return
	var minion := MINION_STATUS.duplicate() as MinionStatus
	minion.bind_master(summoner)
	var effect := StatusEffect.new()
	effect.status = minion
	effect.execute([spook])


func _spook_stats_for_variant(variant: String) -> EnemyStats:
	return SpookEnemyStats.stats_for_variant(variant)


func count_little_skeltons() -> int:
	var n := 0
	for child in get_children():
		if child is Enemy and (child as Enemy).stats is LittleSkeltonEnemyStats:
			n += 1
	return n


func pick_highest_empty_skeleton_slot() -> int:
	var occupied: Dictionary = {}
	for child in get_children():
		if not child is Enemy:
			continue
		if child.has_meta(META_SKELETON_SLOT):
			occupied[int(child.get_meta(META_SKELETON_SLOT))] = true
	for slot in [5, 4, 3, 2, 1]:
		if not occupied.has(slot) and slot_positions.has(slot):
			return slot
	return -1


func try_spawn_little_skelton_from_osteogenesis(summoner: Enemy) -> void:
	spawn_little_skelton(summoner)


func spawn_little_skelton(summoner: Enemy = null) -> Enemy:
	if count_little_skeltons() >= OsteogenesisStatus.MAX_LITTLE_SKELTONS:
		return null
	var slot := pick_highest_empty_skeleton_slot()
	if slot < 0:
		return null
	if not slot_positions.has(slot):
		return null
	
	var new_enemy := instantiate_enemy(LITTLE_SKELTON_STATS)
	add_child(new_enemy)
	new_enemy.stats = LITTLE_SKELTON_STATS
	new_enemy.call_deferred("_apply_battle_spawn_visuals")
	if new_enemy.stats is LittleSkeltonEnemyStats and is_instance_valid(summoner):
		LittleSkeltonEnemyStats.apply_spawned_health_from_summoner(new_enemy.stats, summoner)
	new_enemy.position = slot_positions[slot]
	new_enemy.set_meta(META_SKELETON_SLOT, slot)
	new_enemy.status_handler.statuses_applied.connect(_on_enemy_statuses_applied.bind(new_enemy))
	new_enemy.setup_ai()
	new_enemy.clear_intent_display()
	return new_enemy


func _start_next_enemy_turn() -> void:
	if acting_enemies.is_empty():
		Events.enemy_turn_ended.emit()
		return
	
	var current_enemy := acting_enemies[0]
	
	if not is_instance_valid(current_enemy):
		acting_enemies.erase(current_enemy)
		_start_next_enemy_turn()
		return
	
	if not is_instance_valid(current_enemy.status_handler):
		push_error("EnemyHandler: 敌人 status_handler 无效。")
		return
	
	if is_instance_valid(current_enemy.stats):
		current_enemy.stats.block = 0
	current_enemy.status_handler.apply_statuses_by_type(Status.Type.START_OF_TURN)


func _on_enemy_statuses_applied(type: Status.Type, enemy: Enemy) -> void:
	match type:
		Status.Type.START_OF_TURN:
			enemy.do_turn()
		Status.Type.END_OF_TURN:
			acting_enemies.erase(enemy)
			_start_next_enemy_turn()


func _on_enemy_died(enemy: Enemy) -> void:
	if enemy.stats is SpookEnemyStats:
		GhostSummonerCoordinator.notify_spook_died(self)
	var is_enemy_turn := acting_enemies.size() > 0
	acting_enemies.erase(enemy)
	
	if is_enemy_turn:
		_start_next_enemy_turn()


func _on_enemy_action_completed(enemy: Enemy) -> void:
	## 玩家回合内的插队行动（如影武士迅捷）也会 emit 此信号，但不在 acting_enemies 中；
	## 若仍走 END_OF_TURN 推进，会误触发 enemy_turn_ended → 玩家抽牌/重置能量。
	if not acting_enemies.has(enemy):
		return
	enemy.status_handler.apply_statuses_by_type(Status.Type.END_OF_TURN)


func _should_block_enemy_intent_refresh() -> bool:
	return _intent_reveal_pending or _turn_start_intent_refresh_locked


func _on_player_hand_drawn() -> void:
	if _turn_start_intent_refresh_locked:
		_turn_start_intent_refresh_locked = false
		return
	if _should_block_enemy_intent_refresh():
		return
	if not _any_enemy_intent_visible():
		return
	_refresh_all_enemy_intents()


func _on_player_combat_stat_context_changed() -> void:
	if _player_combat_intent_refresh_depth > 0:
		return
	if _should_block_enemy_intent_refresh():
		return
	if not _any_enemy_intent_visible():
		return
	_player_combat_intent_refresh_depth += 1
	_refresh_all_enemy_intents()
	_player_combat_intent_refresh_depth -= 1


func _any_enemy_intent_visible() -> bool:
	for child in get_children():
		if not _is_live_enemy(child):
			continue
		if (child as Enemy).is_intent_display_visible():
			return true
	return false


func _refresh_all_enemy_intents() -> void:
	for child in get_children():
		if not _is_live_enemy(child):
			continue
		var enemy := child as Enemy
		if enemy.is_intent_suppressed():
			continue
		enemy.update_intent()


## 玩家回合开始：扣敌人身上虚弱/易伤等 debuff 的 duration（覆盖刚结束的敌人回合）。
func tick_enemy_debuffs_at_player_turn_start() -> void:
	for child in get_children():
		if not _is_live_enemy(child):
			continue
		var enemy := child as Enemy
		if is_instance_valid(enemy.status_handler):
			enemy.status_handler.apply_enemy_debuff_ticks_at_player_turn_start()
