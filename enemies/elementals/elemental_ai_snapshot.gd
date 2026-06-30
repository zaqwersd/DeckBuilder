class_name ElementalAISnapshot
extends RefCounted

const KIND_ICE := &"ice"
const KIND_ALT_RANDOM := &"alt_random"


static func combat_snapshot() -> CombatSnapshot:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var run := tree.get_first_node_in_group("run") as Run
	if run == null or run.save_data == null:
		return null
	return run.save_data.combat_snapshot


static func write_spawn_stat_paths(enemies: Array[Enemy]) -> void:
	var snapshot := combat_snapshot()
	if snapshot == null:
		return
	var paths: Dictionary = {}
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy) or enemy.stats == null:
			continue
		var path := String(enemy.stats.resource_path)
		if path.is_empty():
			continue
		paths[enemy.name] = path
	if paths.is_empty():
		return
	snapshot.elemental_spawn_stat_paths = paths


static func write_ai_state(enemy_name: StringName, state: Dictionary) -> void:
	var snapshot := combat_snapshot()
	if snapshot == null or enemy_name.is_empty() or state.is_empty():
		return
	var copy := snapshot.elemental_enemy_ai_states.duplicate(true)
	copy[String(enemy_name)] = state.duplicate(true)
	snapshot.elemental_enemy_ai_states = copy


static func read_ai_state(enemy_name: StringName) -> Dictionary:
	var snapshot := combat_snapshot()
	if snapshot == null or enemy_name.is_empty():
		return {}
	var raw: Variant = snapshot.elemental_enemy_ai_states.get(String(enemy_name))
	return raw as Dictionary if raw is Dictionary else {}


static func read_spawn_stat_path(enemy_name: String) -> String:
	var snapshot := combat_snapshot()
	if snapshot == null:
		return ""
	var raw: Variant = snapshot.elemental_spawn_stat_paths.get(enemy_name)
	return String(raw) if raw != null else ""
