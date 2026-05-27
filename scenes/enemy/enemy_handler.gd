class_name EnemyHandler
extends Node2D

const ENEMY_SCENE := preload("res://scenes/enemy/enemy.tscn")
const LITTLE_SKELTON_STATS := preload("res://enemies/little_skelton/little_skelton_enemy.tres")

const META_SKELETON_SLOT := &"skeleton_slot"

var acting_enemies: Array[Enemy] = []
## 小骷髅等遭遇：槽位编号 1~5 → 布局局部坐标
var slot_positions: Dictionary = {}


func _ready() -> void:
	Events.enemy_died.connect(_on_enemy_died)
	Events.enemy_action_completed.connect(_on_enemy_action_completed)
	Events.player_hand_drawn.connect(_on_player_hand_drawn)
	if not Events.player_combat_stat_context_changed.is_connected(_on_player_combat_stat_context_changed):
		Events.player_combat_stat_context_changed.connect(_on_player_combat_stat_context_changed)


func setup_enemies(battle_stats: BattleStats) -> void:
	if not battle_stats:
		return
	
	slot_positions.clear()
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
		var new_enemy_child := template.duplicate() as Enemy
		add_child(new_enemy_child)
		new_enemy_child.status_handler.statuses_applied.connect(
			_on_enemy_statuses_applied.bind(new_enemy_child)
		)
		if is_instance_valid(template.stats):
			new_enemy_child.stats = template.stats
		if template.has_meta(META_SKELETON_SLOT):
			var slot: int = int(template.get_meta(META_SKELETON_SLOT))
			new_enemy_child.set_meta(META_SKELETON_SLOT, slot)
			if slot_positions.has(slot):
				new_enemy_child.position = slot_positions[slot]
			if new_enemy_child.stats is LittleSkeltonEnemyStats:
				LittleSkeltonEnemyStats.apply_initial_health_for_slot(new_enemy_child.stats, slot)
	
	all_new_enemies.free()
	LittleSkeltonIntentCoordinator.reset_combat()
	CrabIntentCoordinator.reset_combat()
	BoneShewerIntentCoordinator.reset_combat()


func reset_enemy_actions() -> void:
	LittleSkeltonIntentCoordinator.assign_for_handler(self)
	CrabIntentCoordinator.assign_for_handler(self)
	BoneShewerIntentCoordinator.assign_for_handler(self)
	for child in get_children():
		if not child is Enemy:
			continue
		var enemy := child as Enemy
		enemy.current_action = null
		enemy.update_action()


func start_turn() -> void:
	if get_child_count() == 0:
		push_error("EnemyHandler.start_turn: 场上没有敌人。")
		return
	
	var enemies: Array[Enemy] = []
	for child in get_children():
		if child is Enemy and is_instance_valid(child):
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


func try_spawn_little_skelton_from_osteogenesis() -> void:
	spawn_little_skelton()


func spawn_little_skelton() -> Enemy:
	if count_little_skeltons() >= OsteogenesisStatus.MAX_LITTLE_SKELTONS:
		return null
	var slot := pick_highest_empty_skeleton_slot()
	if slot < 0:
		return null
	if not slot_positions.has(slot):
		return null
	
	var new_enemy := ENEMY_SCENE.instantiate() as Enemy
	add_child(new_enemy)
	new_enemy.stats = LITTLE_SKELTON_STATS
	new_enemy.position = slot_positions[slot]
	new_enemy.set_meta(META_SKELETON_SLOT, slot)
	new_enemy.status_handler.statuses_applied.connect(_on_enemy_statuses_applied.bind(new_enemy))
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
	
	current_enemy.status_handler.apply_statuses_by_type(Status.Type.START_OF_TURN)


func _on_enemy_statuses_applied(type: Status.Type, enemy: Enemy) -> void:
	match type:
		Status.Type.START_OF_TURN:
			enemy.do_turn()
		Status.Type.END_OF_TURN:
			acting_enemies.erase(enemy)
			_start_next_enemy_turn()


func _on_enemy_died(enemy: Enemy) -> void:
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


func _on_player_hand_drawn() -> void:
	_refresh_all_enemy_intents()


func _on_player_combat_stat_context_changed() -> void:
	_refresh_all_enemy_intents()


func _refresh_all_enemy_intents() -> void:
	for child in get_children():
		if child is Enemy:
			(child as Enemy).update_intent()
