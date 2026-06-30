class_name EphemeralMuscleStatus
extends Status


## 临时力量状态：持有者下回合开始时失去等量力量

func get_tooltip() -> String:
	return tooltip % format_counter_for_tooltip(stacks)


func apply_status(target: Node) -> void:
	_consume_temporary_strength(target)
	status_applied.emit(self)


func _consume_temporary_strength(target: Node) -> void:
	if target == null:
		return
	var status_handler := target.get("status_handler") as StatusHandler
	if status_handler == null:
		return
	var muscle_status := status_handler.get_status_by_id("muscle") as MuscleStatus
	if muscle_status == null:
		return
	muscle_status.set_stacks(maxi(0, muscle_status.stacks - stacks))
