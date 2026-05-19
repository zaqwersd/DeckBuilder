class_name EphemeralMuscleStatus
extends Status


## 临时力量状态：回合开始时失去等量力量

func get_tooltip() -> String:
	return tooltip % Status.format_tooltip_integer(stacks)


func initialize_status(target: Node) -> void:
	## 保存目标引用，在回合开始时触发
	_status_target = target
	status_applied.connect(_on_status_applied)


var _status_target: Node = null


func _on_status_applied(_status: Status) -> void:
	## 回合开始时：减少玩家的力量
	if _status_target == null:
		return
	var status_handler := _status_target.get("status_handler") as StatusHandler
	if status_handler == null:
		return

	## 获取当前力量状态
	var muscle_status := status_handler.get_status_by_id("muscle") as MuscleStatus
	if muscle_status:
		## 减少力量层数（至少为0）
		var new_stacks := maxi(0, muscle_status.stacks - self.stacks)
		muscle_status.set_stacks(new_stacks)
