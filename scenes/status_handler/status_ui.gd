class_name StatusUI
extends Control

## 与 `CardUpgradeUiColors.BB_NEGATIVE_REMOVABLE`（#f36c60）一致
const HARMFUL_COUNTER_COLOR := Color(0xf3 / 255.0, 0x6c / 255.0, 0x60 / 255.0, 1.0)
## 状态图标角标（层数 / 回合 / 下标）统一字号，与 Stacks、Duration 一致。
const COUNTER_FONT_SIZE := 21


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
	_sync_counter_label_font_sizes()
	_apply_square_cell()


func set_status(new_status: Status) -> void:
	if not is_node_ready():
		await ready
		
	# 确保节点引用已初始化
	if superscript == null:
		superscript = get_node_or_null("Superscript")
	if subscript == null:
		subscript = get_node_or_null("Subscript")
	_sync_counter_label_font_sizes()
	
	status = new_status
	icon.texture = status.icon
	icon.modulate = Color.WHITE
	
	var is_overwhelming := status.id == "overwhelming"
	var is_alert := status.id == "alert"
	var is_heavy_armor := status.id == "heavy_armor"
	var is_swift := status.id == "swift"
	var is_next_turn_mana := status.id == "next_turn_mana"
	
	if is_heavy_armor and superscript != null and subscript != null:
		duration.visible = false
		stacks.visible = false
		var armor := status as HeavyArmorStatus
		if armor:
			_set_superscript_value(armor.threshold_n)
			_set_subscript_value(armor.accumulated_m)
	elif is_alert and subscript != null:
		duration.visible = false
		stacks.visible = false
		if superscript != null:
			superscript.visible = false
		var alert := status as AlertStatus
		_set_subscript_value(alert.turns_until_wake if alert else 0)
	elif is_swift and subscript != null:
		duration.visible = false
		stacks.visible = false
		if superscript != null:
			superscript.visible = false
		var swift := status as SwiftStatus
		_set_subscript_value(swift.cards_toward_trigger if swift else 0)
	elif is_next_turn_mana and subscript != null:
		_apply_next_turn_mana_labels(status as NextTurnManaStatus)
	elif is_overwhelming and superscript != null and subscript != null:
		duration.visible = false
		stacks.visible = false
		superscript.visible = true
		subscript.visible = true
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
	var is_alert := status.id == "alert"
	var is_heavy_armor := status.id == "heavy_armor"
	var is_swift := status.id == "swift"
	var is_next_turn_mana := status.id == "next_turn_mana"
	
	if is_heavy_armor and superscript != null and subscript != null:
		duration.visible = false
		stacks.visible = false
		var armor := status as HeavyArmorStatus
		if armor:
			_set_superscript_value(armor.threshold_n)
			_set_subscript_value(armor.accumulated_m)
	elif is_alert and subscript != null:
		duration.visible = false
		stacks.visible = false
		if superscript != null:
			superscript.visible = false
		var alert := status as AlertStatus
		_set_subscript_value(alert.turns_until_wake if alert else 0)
	elif is_swift and subscript != null:
		duration.visible = false
		stacks.visible = false
		if superscript != null:
			superscript.visible = false
		var swift_status := status as SwiftStatus
		_set_subscript_value(swift_status.cards_toward_trigger if swift_status else 0)
	elif is_next_turn_mana and subscript != null:
		_apply_next_turn_mana_labels(status as NextTurnManaStatus)
	elif is_overwhelming and superscript != null and subscript != null:
		var overwhelming := status as OverwhelmingStatus
		if overwhelming:
			_set_superscript_value(overwhelming.stacks)
			_set_subscript_value(overwhelming.damage_multiplier + overwhelming.stacks)
		else:
			_set_superscript_value(status.stacks)
			_set_subscript_value(1 + status.stacks)
	else:
		# 普通状态（力量、敏捷、易伤层数/回合等）
		duration.text = str(status.duration)
		stacks.text = str(status.stacks)
		_apply_counter_value_color(duration, status.duration)
		_apply_counter_value_color(stacks, status.stacks)


func _apply_next_turn_mana_labels(next_mana: NextTurnManaStatus) -> void:
	duration.visible = false
	stacks.visible = false
	if superscript != null:
		superscript.visible = false
	_set_subscript_value(next_mana.mana_to_grant if next_mana else 0)


func _sync_counter_label_font_sizes() -> void:
	for label: Label in [duration, stacks, superscript, subscript]:
		if label != null:
			label.add_theme_font_size_override("font_size", COUNTER_FONT_SIZE)


func _set_subscript_value(value: int) -> void:
	if subscript == null:
		return
	subscript.visible = true
	subscript.text = str(value)
	_apply_counter_value_color(subscript, value)


func _set_superscript_value(value: int) -> void:
	if superscript == null:
		return
	superscript.visible = true
	superscript.text = str(value)
	_apply_counter_value_color(superscript, value)


func _apply_counter_value_color(label: Label, value: int) -> void:
	if label == null:
		return
	if status != null and status.counter_shows_as_harmful(value):
		label.add_theme_color_override("font_color", HARMFUL_COUNTER_COLOR)
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
