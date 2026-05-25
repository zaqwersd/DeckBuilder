class_name IgneousVolatileStatus
extends Status


func get_tooltip() -> String:
	return tooltip % format_counter_for_tooltip(stacks)
