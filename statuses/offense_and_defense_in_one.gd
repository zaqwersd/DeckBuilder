class_name OffenseAndDefenseInOneStatus
extends Status

var _owner: Player


func initialize_status(target: Node) -> void:
	_owner = target as Player
	if _owner == null:
		return
	if not Events.player_attack_card_damage_value_to_enemy.is_connected(_on_player_attack_card_damage_value):
		Events.player_attack_card_damage_value_to_enemy.connect(_on_player_attack_card_damage_value)


func deactivate_status(_target: Node) -> void:
	if Events.player_attack_card_damage_value_to_enemy.is_connected(_on_player_attack_card_damage_value):
		Events.player_attack_card_damage_value_to_enemy.disconnect(_on_player_attack_card_damage_value)
	_owner = null


func get_tooltip() -> String:
	return tooltip


func apply_status(_target: Node) -> void:
	status_applied.emit(self)


func _on_player_attack_card_damage_value(_enemy: Enemy, amount: int) -> void:
	if amount <= 0 or Events.is_combat_ended():
		return
	if not is_instance_valid(_owner):
		return
	var block_effect := BlockEffect.new()
	block_effect.amount = amount
	block_effect.execute([_owner])