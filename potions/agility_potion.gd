extends Potion

const DEXTERITY_STATUS := preload("res://statuses/dexterity.tres")

@export var dexterity_stacks := 2


func perform_use(targets: Array[Node]) -> void:
	if targets.is_empty():
		return
	var status_effect := StatusEffect.new()
	var dex := DEXTERITY_STATUS.duplicate(true)
	if dex:
		dex.stacks = dexterity_stacks
	status_effect.status = dex
	status_effect.execute(targets)
