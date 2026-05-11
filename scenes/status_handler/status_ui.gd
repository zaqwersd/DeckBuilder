class_name StatusUI
extends Control

const NEGATIVE_VALUE_COLOR := Color(1.0, 0.0, 0.0)

@export var status: Status : set = set_status

@onready var icon: TextureRect = $Icon
@onready var duration: Label = $Duration
@onready var stacks: Label = $Stacks


func set_status(new_status: Status) -> void:
	if not is_node_ready():
		await ready
	
	status = new_status
	icon.texture = status.icon
	duration.visible = status.stack_type == Status.StackType.DURATION
	stacks.visible = status.stack_type == Status.StackType.INTENSITY
	custom_minimum_size = icon.get_combined_minimum_size()
	
	if duration.visible:
		custom_minimum_size = duration.size + duration.position
	elif stacks.visible:
		custom_minimum_size = stacks.size + stacks.position
	
	if not status.status_changed.is_connected(_on_status_changed):
		status.status_changed.connect(_on_status_changed)
	
	_on_status_changed()


func _on_status_changed() -> void:
	if not status:
		return

	if status.can_expire and status.duration <= 0:
		queue_free()
		
	if status.stack_type == Status.StackType.INTENSITY and status.stacks == 0:
		queue_free()

	duration.text = str(status.duration)
	stacks.text = str(status.stacks)
	_apply_negative_value_color(duration, status.duration)
	_apply_negative_value_color(stacks, status.stacks)


func _apply_negative_value_color(label: Label, value: int) -> void:
	if value < 0:
		label.add_theme_color_override("font_color", NEGATIVE_VALUE_COLOR)
	else:
		label.remove_theme_color_override("font_color")
