extends Relic

const WEAK_STATUS := preload("res://statuses/weak.tres")
const VULNERABLE_STATUS := preload("res://statuses/vulnerable.tres")

@export var duration := 1


func activate_relic(owner: RelicUI) -> void:
	var enemies := _alive_enemies(owner)
	if enemies.is_empty():
		return
	_apply_status_to_all(WEAK_STATUS, enemies)
	_apply_status_to_all(VULNERABLE_STATUS, enemies)
	owner.flash()


func _apply_status_to_all(template: Status, enemies: Array[Node]) -> void:
	var status_effect := StatusEffect.new()
	var st := template.duplicate(true) as Status
	st.duration = duration
	status_effect.status = st
	status_effect.execute(enemies)


func _alive_enemies(owner: RelicUI) -> Array[Node]:
	var out: Array[Node] = []
	if owner == null or not is_instance_valid(owner):
		return out
	for node in owner.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or not (node is Enemy):
			continue
		var enemy := node as Enemy
		if enemy.stats != null and enemy.stats.health > 0:
			out.append(enemy)
	return out