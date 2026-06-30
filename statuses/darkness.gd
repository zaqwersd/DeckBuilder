class_name DarknessStatus
extends Status

const STRENGTH_STATUS := preload("res://statuses/strength.tres")

func get_tooltip() -> String:
	return tooltip % format_counter_for_tooltip(stacks)


func apply_status(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		status_applied.emit(self)
		return
	var strength := STRENGTH_STATUS.duplicate(true) as Status
	strength.stacks = stacks
	var effect := StatusEffect.new()
	effect.status = strength
	effect.execute([target])
	status_applied.emit(self)