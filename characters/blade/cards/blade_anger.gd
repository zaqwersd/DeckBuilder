extends Card

const MUSCLE_STATUS = preload("res://statuses/strength.tres")

const STRENGTH_STACKS := 3


func get_default_tooltip() -> String:
	return tooltip_text % STRENGTH_STACKS


func get_updated_tooltip(_player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler) -> String:
	return tooltip_text % bbcode_for_modified_number(STRENGTH_STACKS, STRENGTH_STACKS)


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var status_effect := StatusEffect.new()
	var muscle := MUSCLE_STATUS.duplicate()
	muscle.stacks = STRENGTH_STACKS
	status_effect.status = muscle
	status_effect.execute(targets)
