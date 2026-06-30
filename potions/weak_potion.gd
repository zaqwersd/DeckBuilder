extends Potion

const WEAK_STATUS := preload("res://statuses/weak.tres")

@export var layers := 3


func perform_use(targets: Array[Node]) -> void:
	if targets.is_empty():
		return
	var weak := WEAK_STATUS.duplicate()
	weak.duration = layers
	var status_effect := StatusEffect.new()
	status_effect.status = weak
	status_effect.execute(targets)
