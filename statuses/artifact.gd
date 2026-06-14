class_name ArtifactStatus
extends Status

signal artifact_consumed


func get_tooltip() -> String:
	return (
		"免疫受到的下%s次负面效果。"
		% format_counter_for_tooltip(stacks)
	)


func consume_one() -> void:
	if stacks <= 0:
		return
	set_stacks(stacks - 1)
	artifact_consumed.emit()


static func get_on(target: Node2D) -> ArtifactStatus:
	if target == null:
		return null
	var handler: StatusHandler = target.get("status_handler") as StatusHandler
	if handler == null:
		return null
	return handler.get_status_by_id("artifact") as ArtifactStatus
