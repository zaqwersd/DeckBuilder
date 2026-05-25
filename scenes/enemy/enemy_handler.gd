class_name EnemyHandler
extends Node2D

var acting_enemies: Array[Enemy] = []


func _ready() -> void:
	Events.enemy_died.connect(_on_enemy_died)
	Events.enemy_action_completed.connect(_on_enemy_action_completed)
	Events.player_hand_drawn.connect(_on_player_hand_drawn)


func setup_enemies(battle_stats: BattleStats) -> void:
	if not battle_stats:
		return
	
	for enemy: Enemy in get_children():
		enemy.free()
	
	var all_new_enemies := battle_stats.enemies.instantiate()
	
	for new_enemy: Node2D in all_new_enemies.get_children():
		var template := new_enemy as Enemy
		if template == null:
			continue
		var new_enemy_child := template.duplicate() as Enemy
		add_child(new_enemy_child)
		new_enemy_child.status_handler.statuses_applied.connect(_on_enemy_statuses_applied.bind(new_enemy_child))
		# duplicate() 后导出 Resource 偶发为 null，用模板再赋一次以触发 create_instance
		if is_instance_valid(template.stats):
			new_enemy_child.stats = template.stats
		
	all_new_enemies.free()


func reset_enemy_actions() -> void:
	for enemy: Enemy in get_children():
		enemy.current_action = null
		enemy.update_action()


func start_turn() -> void:
	if get_child_count() == 0:
		push_error("EnemyHandler.start_turn: 场上没有敌人。")
		return
	
	acting_enemies.clear()
	for child in get_children():
		if child is Enemy and is_instance_valid(child):
			acting_enemies.append(child as Enemy)
	
	_start_next_enemy_turn()


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
	for enemy: Enemy in get_children():
		enemy.update_intent()
