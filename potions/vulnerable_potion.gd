extends Potion

const VULNERABLE_STATUS := preload("res://statuses/vulnerable.tres")

@export var layers := 3


func perform_use(targets: Array[Node]) -> void:
	if targets.is_empty():
		return
	var vulnerable := VULNERABLE_STATUS.duplicate()
	vulnerable.duration = layers
	var status_effect := StatusEffect.new()
	status_effect.status = vulnerable
	status_effect.execute(targets)
