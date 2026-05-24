extends Relic

@export var max_health_bonus := 10


func apply_persistent_pickup_on_acquire(_run: Node) -> void:
	var run := _run as Run
	if run == null or not is_instance_valid(run.character):
		return
	run.character.max_health += max_health_bonus


func revert_persistent_pickup_on_rollback(ch: CharacterStats) -> void:
	if ch == null:
		return
	ch.max_health -= max_health_bonus
	if ch.health > ch.max_health:
		ch.health = ch.max_health
