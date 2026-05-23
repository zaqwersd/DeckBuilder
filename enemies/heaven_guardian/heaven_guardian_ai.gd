class_name HeavenGuardianAI
extends EnemyActionPicker

const HEAVY_ARMOR := preload("res://statuses/heavy_armor.tres")

var _armor_spawned := false


func _set_enemy(value: Enemy) -> void:
	super._set_enemy(value)
	if is_inside_tree():
		call_deferred("_spawn_heavy_armor_if_needed")


func _ready() -> void:
	super._ready()
	call_deferred("_spawn_heavy_armor_if_needed")


func _spawn_heavy_armor_if_needed() -> void:
	if _armor_spawned or not is_instance_valid(enemy) or enemy.status_handler == null:
		return
	if enemy.status_handler.get_status_by_id("heavy_armor") != null:
		_armor_spawned = true
		return
	var armor := HEAVY_ARMOR.duplicate() as HeavyArmorStatus
	var se := StatusEffect.new()
	se.status = armor
	se.execute([enemy])
	_armor_spawned = true


func get_action() -> EnemyAction:
	var armor := HeavyArmorStatus.get_on_enemy(enemy)
	if armor != null and armor.stun_next_enemy_turn:
		return $Stunned as EnemyAction
	return $Strike36Strength10 as EnemyAction


func get_first_conditional_action() -> EnemyAction:
	return null
