extends Node2D

const ELEMENT_SCENE := preload("res://enemies/elementals/elemental_enemy.tscn")
const ELEMENT_STATS: Array[EnemyStats] = [
	preload("res://enemies/elementals/fire_elemental.tres"),
	preload("res://enemies/elementals/ice_elemental.tres"),
	preload("res://enemies/elementals/iron_elemental.tres"),
	preload("res://enemies/elementals/dark_elemental.tres"),
	preload("res://enemies/elementals/electronic_elemental.tres"),
]
const POSITIONS := [Vector2(770, 320), Vector2(990, 320)]
const SPAWN_COUNT := 2


func _init() -> void:
	_spawn_elements(SPAWN_COUNT)


func _spawn_elements(count: int) -> void:
	if _try_restore_spawn_from_snapshot(count):
		return
	var pool := ELEMENT_STATS.duplicate()
	RNG.array_shuffle(pool)
	for i in range(mini(count, pool.size())):
		_add_elemental_enemy("Enemy%d" % (i + 1), POSITIONS[i], pool[i])


func _try_restore_spawn_from_snapshot(count: int) -> bool:
	for i in range(count):
		var enemy_name := "Enemy%d" % (i + 1)
		var path := ElementalAISnapshot.read_spawn_stat_path(enemy_name)
		if path.is_empty():
			return false
		var stats_res := load(path) as EnemyStats
		if stats_res == null:
			return false
		_add_elemental_enemy(enemy_name, POSITIONS[i], stats_res)
	return true


func _add_elemental_enemy(enemy_name: String, pos: Vector2, stats_res: EnemyStats) -> void:
	var enemy := ELEMENT_SCENE.instantiate() as Enemy
	enemy.name = enemy_name
	enemy.position = pos
	enemy.stats = stats_res
	add_child(enemy)
