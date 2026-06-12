class_name SpiderEnemyStats
extends EnemyStats

const MAX_HEALTH := 46


func create_instance() -> Resource:
	var instance := super.create_instance() as EnemyStats
	instance.max_health = MAX_HEALTH
	instance.health = MAX_HEALTH
	return instance


func setup_battle_visual(enemy: Enemy) -> void:
	SpiderEnemyVisual.attach_to(enemy)
