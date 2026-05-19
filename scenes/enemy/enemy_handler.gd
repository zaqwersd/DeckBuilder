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
		enemy.queue_free()
	
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
		
	all_new_enemies.queue_free()


func reset_enemy_actions() -> void:
	for enemy: Enemy in get_children():
		enemy.current_action = null
		enemy.update_action()


func start_turn() -> void:
	print("[DEBUG] ==========================================")
	print("[DEBUG] enemy_handler start_turn called")
	print("[DEBUG] self: ", self)
	print("[DEBUG] is_instance_valid: ", is_instance_valid(self))
	print("[DEBUG] is_inside_tree: ", is_inside_tree())
	print("[DEBUG] child count: ", get_child_count())
	if get_child_count() == 0:
		push_error("[DEBUG] No enemies found!")
		return
	
	print("[DEBUG] Clearing acting_enemies...")
	acting_enemies.clear()
	print("[DEBUG] Populating acting_enemies from children...")
	for child in get_children():
		print("[DEBUG] Checking child: ", child.name, " type: ", child.get_class())
		if child is Enemy:
			var enemy := child as Enemy
			print("[DEBUG] Found enemy: ", enemy.name, " valid: ", is_instance_valid(enemy))
			if is_instance_valid(enemy):
				acting_enemies.append(enemy)
		else:
			print("[DEBUG] Child is not Enemy, skipping: ", child.name)
	
	print("[DEBUG] acting_enemies count after population: ", acting_enemies.size())
	print("[DEBUG] About to call _start_next_enemy_turn...")
	_start_next_enemy_turn()
	print("[DEBUG] _start_next_enemy_turn returned")


func _start_next_enemy_turn() -> void:
	print("[DEBUG] _start_next_enemy_turn called, acting_enemies count: ", acting_enemies.size())
	if acting_enemies.is_empty():
		print("[DEBUG] acting_enemies is empty, emitting enemy_turn_ended")
		Events.enemy_turn_ended.emit()
		return
	
	var current_enemy := acting_enemies[0]
	print("[DEBUG] Current enemy: ", current_enemy.name if current_enemy else "null", " valid: ", is_instance_valid(current_enemy))
	
	if not is_instance_valid(current_enemy):
		push_error("[DEBUG] Current enemy is invalid!")
		acting_enemies.erase(current_enemy)
		_start_next_enemy_turn()
		return
	
	if not is_instance_valid(current_enemy.status_handler):
		push_error("[DEBUG] Enemy status_handler is invalid!")
		return
	
	print("[DEBUG] Applying START_OF_TURN to enemy: ", current_enemy.name)
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
	enemy.status_handler.apply_statuses_by_type(Status.Type.END_OF_TURN)


func _on_player_hand_drawn() -> void:
	for enemy: Enemy in get_children():
		enemy.update_intent()
