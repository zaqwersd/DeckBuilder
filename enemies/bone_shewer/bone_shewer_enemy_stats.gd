class_name BoneShewerEnemyStats
extends EnemyStats

const MAX_HEALTH := 98


func create_instance() -> Resource:
	var instance := super.create_instance() as EnemyStats
	instance.max_health = MAX_HEALTH
	instance.health = MAX_HEALTH
	return instance
