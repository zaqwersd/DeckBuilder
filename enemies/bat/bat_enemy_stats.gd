class_name BatEnemyStats
extends EnemyStats

const MIN_HEALTH := 18
const MAX_HEALTH := 24


func create_instance() -> Resource:
	var instance := super.create_instance() as EnemyStats
	var rolled := RNG.instance.randi_range(MIN_HEALTH, MAX_HEALTH)
	instance.max_health = rolled
	instance.health = rolled
	return instance
