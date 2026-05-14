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
	
	# 检查是否是巨剑状态（overwhelming），需要特殊显示上下标
	var is_overwhelming := status.id == "overwhelming"
	
	if is_overwhelming and superscript != null and subscript != null:
		# 巨剑状态：使用上下标显示
		duration.visible = false
		stacks.visible = false
		superscript.visible = true
		subscript.visible = true
		custom_minimum_size = icon.get_combined_minimum_size()
	else:
		# 普通状态：使用原有显示方式
		duration.visible = status.stack_type == Status.StackType.DURATION
		stacks.visible = status.stack_type == Status.StackType.INTENSITY
		if superscript != null:
			superscript.visible = false
		if subscript != null:
			subscript.visible = false
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

	# 检查是否是巨剑状态
	var is_overwhelming := status.id == "overwhelming"
	
	if is_overwhelming and superscript != null and subscript != null:
		# 巨剑状态：上标=耗能增加量（stacks），下标=伤害倍数（damage_multiplier + stacks）
		var overwhelming := status as OverwhelmingStatus
		if overwhelming:
			superscript.text = str(overwhelming.stacks)
			subscript.text = str(overwhelming.damage_multiplier + overwhelming.stacks)
			_apply_negative_value_color(superscript, overwhelming.stacks)
			_apply_negative_value_color(subscript, overwhelming.damage_multiplier + overwhelming.stacks)
		else:
			# 如果转型失败，显示基本值
			superscript.text = str(status.stacks)
			subscript.text = str(1 + status.stacks)
	else:
		# 普通状态
		duration.text = str(status.duration)
		stacks.text = str(status.stacks)
		_apply_negative_value_color(duration, status.duration)
		_apply_negative_value_color(stacks, status.stacks)


func _apply_negative_value_color(label: Label, value: int) -> void:
	if value < 0:
		label.add_theme_color_override("font_color", NEGATIVE_VALUE_COLOR)
	else:
		label.remove_theme_color_override("font_color")
