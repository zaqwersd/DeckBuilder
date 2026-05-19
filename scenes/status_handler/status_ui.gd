class_name StatusUI
extends Control

const NEGATIVE_VALUE_COLOR := Color(1.0, 0.0, 0.0)


@export var status: Status : set = set_status

@onready var icon: TextureRect = $Icon
@onready var duration: Label = $Duration
@onready var stacks: Label = $Stacks
@onready var superscript: Label
@onready var subscript: Label


func _ready() -> void:
	# 动态获取可选的上下标节点（某些状态需要）
	superscript = get_node_or_null("Superscript")
	subscript = get_node_or_null("Subscript")
	_apply_square_cell()


func set_status(new_status: Status) -> void:
	if not is_node_ready():
		await ready
		
	# 确保节点引用已初始化
	if superscript == null:
		superscript = get_node_or_null("Superscript")
	if subscript == null:
		subscript = get_node_or_null("Subscript")
	
	status = new_status
	icon.texture = status.icon
	
	var is_overwhelming := status.id == "overwhelming"
	var is_flow := status.id == "flow_state"
	
	if (is_overwhelming or is_flow) and superscript != null and subscript != null:
		duration.visible = false
		stacks.visible = false
		if is_overwhelming:
			superscript.visible = true
			subscript.visible = true
		elif is_flow:
			_apply_flow_state_labels(status as FlowStateStatus)
	else:
		# 普通状态：使用原有显示方式
		duration.visible = status.stack_type == Status.StackType.DURATION
		stacks.visible = status.stack_type == Status.StackType.INTENSITY
		if superscript != null:
			superscript.visible = false
		if subscript != null:
			subscript.visible = false

	_apply_square_cell()

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

	var is_overwhelming := status.id == "overwhelming"
	var is_flow := status.id == "flow_state"
	
	if is_overwhelming and superscript != null and subscript != null:
		var overwhelming := status as OverwhelmingStatus
		if overwhelming:
			superscript.visible = true
			subscript.visible = true
			superscript.text = str(overwhelming.stacks)
			subscript.text = str(overwhelming.damage_multiplier + overwhelming.stacks)
			_apply_negative_value_color(superscript, overwhelming.stacks)
			_apply_negative_value_color(subscript, overwhelming.damage_multiplier + overwhelming.stacks)
		else:
			superscript.visible = true
			subscript.visible = true
			superscript.text = str(status.stacks)
			subscript.text = str(1 + status.stacks)
	elif is_flow and superscript != null and subscript != null:
		_apply_flow_state_labels(status as FlowStateStatus)
	else:
		# 普通状态
		duration.text = str(status.duration)
		stacks.text = str(status.stacks)
		_apply_negative_value_color(duration, status.duration)
		_apply_negative_value_color(stacks, status.stacks)


func _apply_flow_state_labels(flow: FlowStateStatus) -> void:
	if flow == null:
		if superscript != null:
			superscript.visible = false
		if subscript != null:
			subscript.visible = false
		return
	if superscript != null:
		superscript.visible = flow.draw_on_exhaust > 0
		if superscript.visible:
			superscript.text = str(flow.draw_on_exhaust)
			_apply_negative_value_color(superscript, flow.draw_on_exhaust)
	if subscript != null:
		subscript.visible = flow.mana_on_exhaust > 0
		if subscript.visible:
			subscript.text = str(flow.mana_on_exhaust)
			_apply_negative_value_color(subscript, flow.mana_on_exhaust)


func _apply_negative_value_color(label: Label, value: int) -> void:
	if value < 0:
		label.add_theme_color_override("font_color", NEGATIVE_VALUE_COLOR)
	else:
		label.remove_theme_color_override("font_color")


func _cell_side() -> float:
	if is_instance_valid(icon):
		return maxf(icon.custom_minimum_size.x, icon.custom_minimum_size.y)
	return 33.0


## 正方形仅用于 StatusHandler 横向排版的占位；层数/上下标可画出槽位外，仍完整显示。
func _apply_square_cell() -> void:
	var side := _cell_side()
	custom_minimum_size = Vector2(side, side)
	clip_contents = false
	icon.position = Vector2.ZERO
	icon.size = Vector2(side, side)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
