class_name StatusUI
extends Control

## 与 `CardUpgradeUiColors.BB_NEGATIVE_REMOVABLE`（#f36c60）一致
const HARMFUL_COUNTER_COLOR := Color(0xf3 / 255.0, 0x6c / 255.0, 0x60 / 255.0, 1.0)
## 状态图标角标（层数 / 回合 / 下标）统一字号，与 Stacks、Duration 一致。
const COUNTER_FONT_SIZE := 21
## 参考边长（与 `StatusHandler.ICON_CELL_SIZE` 一致）；实际布局按 `_cell_side()` 等比缩放。
const CELL_REF_SIDE := 33.0
## 方格内固定槽位（像素，基于 CELL_REF_SIDE）；上标右上、下标/层数/回合右下。
const SUPERSCRIPT_SLOT := Rect2(21.0, 0.0, 16.0, 15.0)
const SUBSCRIPT_SLOT := Rect2(21.0, 18.0, 16.0, 15.0)


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
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not mouse_entered.is_connected(_on_mouse_entered_status):
		mouse_entered.connect(_on_mouse_entered_status)
	if not mouse_exited.is_connected(_on_mouse_exited_status):
		mouse_exited.connect(_on_mouse_exited_status)


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
	var is_sins := status.id == "sins"
	var is_next_turn_mana := status.id == "next_turn_mana"
	var is_card_free := status.id == "card_free"
	var is_malice := status.id == "malice_state"
	var is_infinite := status.id == "infinite_state"
	var is_hard_shell := status.id == "hard_shell"

	if is_malice and subscript != null:
		duration.visible = false
		stacks.visible = false
		if superscript != null:
			superscript.visible = false
		var malice := status as MaliceStatus
		_set_subscript_value(malice.m if malice else 0)
	elif is_infinite and subscript != null:
		duration.visible = false
		stacks.visible = false
		if superscript != null:
			superscript.visible = false
		_set_subscript_value(status.stacks)
	elif is_heavy_armor and superscript != null and subscript != null:
		duration.visible = false
		stacks.visible = false
		var armor := status as HeavyArmorStatus
		if armor:
			_set_superscript_value(armor.threshold_n)
			_set_subscript_value(armor.accumulated_m)
	elif is_hard_shell and subscript != null:
		_apply_hard_shell_labels(status as HardShellStatus)
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
	elif is_sins and subscript != null:
		duration.visible = false
		stacks.visible = false
		if superscript != null:
			superscript.visible = false
		var sins := status as SinsStatus
		_set_subscript_value(sins.draws_until_profane if sins else SinsStatus.DRAWS_PER_PROFANE)
	elif is_next_turn_mana and subscript != null:
		_apply_next_turn_mana_labels(status as NextTurnManaStatus)
	elif is_card_free and subscript != null:
		duration.visible = false
		stacks.visible = false
		if superscript != null:
			superscript.visible = false
		_set_subscript_value(status.stacks)
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

	if _should_remove_status_ui():
		_remove_status_ui()
		return

	var is_overwhelming := status.id == "overwhelming"
	var is_alert := status.id == "alert"
	var is_heavy_armor := status.id == "heavy_armor"
	var is_swift := status.id == "swift"
	var is_sins := status.id == "sins"
	var is_next_turn_mana := status.id == "next_turn_mana"
	var is_card_free := status.id == "card_free"
	var is_malice := status.id == "malice_state"
	var is_infinite := status.id == "infinite_state"
	var is_hard_shell := status.id == "hard_shell"

	if is_malice and subscript != null:
		duration.visible = false
		stacks.visible = false
		if superscript != null:
			superscript.visible = false
		var malice := status as MaliceStatus
		_set_subscript_value(malice.m if malice else 0)
	elif is_infinite and subscript != null:
		duration.visible = false
		stacks.visible = false
		if superscript != null:
			superscript.visible = false
		_set_subscript_value(status.stacks)
	elif is_heavy_armor and superscript != null and subscript != null:
		duration.visible = false
		stacks.visible = false
		var armor := status as HeavyArmorStatus
		if armor:
			_set_superscript_value(armor.threshold_n)
			_set_subscript_value(armor.accumulated_m)
	elif is_hard_shell and subscript != null:
		_apply_hard_shell_labels(status as HardShellStatus)
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
	elif is_sins and subscript != null:
		duration.visible = false
		stacks.visible = false
		if superscript != null:
			superscript.visible = false
		var sins_status := status as SinsStatus
		_set_subscript_value(sins_status.draws_until_profane if sins_status else SinsStatus.DRAWS_PER_PROFANE)
	elif is_next_turn_mana and subscript != null:
		_apply_next_turn_mana_labels(status as NextTurnManaStatus)
	elif is_card_free and subscript != null:
		duration.visible = false
		stacks.visible = false
		if superscript != null:
			superscript.visible = false
		_set_subscript_value(status.stacks)
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


func _apply_hard_shell_labels(hard_shell: HardShellStatus) -> void:
	duration.visible = false
	stacks.visible = false
	if superscript != null:
		superscript.visible = false
	if hard_shell == null:
		icon.modulate = Color.WHITE
		if subscript != null:
			subscript.visible = false
		return
	if hard_shell.shell_active:
		icon.modulate = Color.WHITE
		_set_subscript_value(hard_shell.block_index)
	else:
		icon.modulate = HardShellStatus.SPENT_ICON_MODULATE
		if subscript != null:
			subscript.visible = false


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


func _should_remove_status_ui() -> bool:
	if status.can_expire and status.duration <= 0:
		return true
	if status.stack_type == Status.StackType.INTENSITY and status.stacks == 0:
		return true
	return false


func _status_handler() -> StatusHandler:
	var node := get_parent()
	while node != null:
		if node is StatusHandler:
			return node as StatusHandler
		node = node.get_parent()
	return null


func _remove_status_ui() -> void:
	var handler := _status_handler()
	if handler != null:
		status.deactivate_status(handler.status_owner)
	queue_free()


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
	_layout_counter_labels(side)


func _layout_counter_labels(side: float) -> void:
	var scale := side / CELL_REF_SIDE
	_apply_counter_slot(superscript, SUPERSCRIPT_SLOT, scale)
	_apply_counter_slot(subscript, SUBSCRIPT_SLOT, scale)
	_apply_counter_slot(stacks, SUBSCRIPT_SLOT, scale)
	_apply_counter_slot(duration, SUBSCRIPT_SLOT, scale)


func _apply_counter_slot(label: Label, slot: Rect2, scale: float) -> void:
	if label == null:
		return
	label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	label.offset_left = 0.0
	label.offset_top = 0.0
	label.offset_right = 0.0
	label.offset_bottom = 0.0
	label.position = slot.position * scale
	label.size = slot.size * scale
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _on_mouse_entered_status() -> void:
	if status == null or Events.is_combat_ended():
		return
	var sh := _status_handler()
	var open_right := sh.tooltips_open_to_right if sh else true
	Events.status_tooltip_hover_show.emit(status, self, open_right)


func _on_mouse_exited_status() -> void:
	call_deferred("_deferred_emit_status_tooltip_hide")


func _deferred_emit_status_tooltip_hide() -> void:
	var sh := _status_handler()
	if sh != null and sh.is_pointer_over_status_ui(self):
		return
	Events.status_tooltip_hover_hide.emit()
