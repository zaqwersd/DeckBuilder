class_name IgneousVolatileStatus
extends Status


func get_tooltip() -> String:
	return tooltip % Status.format_tooltip_integer(stacks)
