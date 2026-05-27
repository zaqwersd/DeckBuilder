extends Potion

const STRENGTH_STATUS := preload("res://statuses/strength.tres")

@export var strength_stacks := 2


func perform_use(targets: Array[Node]) -> void:
	if targets.is_empty():
		return
	var status_effect := StatusEffect.new()
	var muscle := STRENGTH_STATUS.duplicate(true)
	if muscle:
		muscle.stacks = strength_stacks
	status_effect.status = muscle
	status_effect.execute(targets)
