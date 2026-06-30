@tool
class_name ElementalEnemyStats
extends EnemyStats

@export var initial_statuses: Array[Status] = []


func create_instance() -> Resource:
	var instance := super.create_instance() as ElementalEnemyStats
	instance.max_health = 32
	instance.health = 32
	instance.initial_statuses = []
	for st: Status in initial_statuses:
		if st != null:
			instance.initial_statuses.append(st.duplicate(true) as Status)
	return instance


func setup_battle_visual(enemy: Node) -> void:
	if enemy is Enemy:
		(enemy as Enemy).start_floating_motion()
	if Engine.is_editor_hint():
		return
	if enemy is Enemy and (enemy as Enemy).has_meta(&"_initial_statuses_applied"):
		return
	if enemy is Enemy:
		(enemy as Enemy).set_meta(&"_initial_statuses_applied", true)
	_apply_initial_statuses.call_deferred(enemy)


func _apply_initial_statuses(enemy: Node) -> void:
	if not is_instance_valid(enemy) or not enemy is Enemy:
		return
	var e := enemy as Enemy
	if not is_instance_valid(e.status_handler):
		return
	for st: Status in initial_statuses:
		if st == null:
			continue
		var effect := StatusEffect.new()
		effect.status = st.duplicate(true) as Status
		effect.execute([e])