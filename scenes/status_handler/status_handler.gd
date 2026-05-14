class_name StatusHandler
extends HBoxContainer

signal statuses_applied(type: Status.Type)

const STATUS_APPLY_INTERVAL := 0.25
const STATUS_UI = preload("res://scenes/status_handler/status_ui.tscn")

@export var status_owner: Node2D
## 由 StatusBar 设置：玩家 true（说明在右），敌人 false（说明在左）
var tooltips_open_to_right: bool = true


func apply_statuses_by_type(type: Status.Type) -> void:
	if type == Status.Type.EVENT_BASED:
		return
		
	var status_queue: Array[Status] = _get_all_statuses().filter(
		func(status: Status):
			return status.type == type
	)
	if status_queue.is_empty():
		statuses_applied.emit(type)
		return
	
	if Events.is_combat_ended():
		for status: Status in status_queue:
			status.apply_status(status_owner)
		statuses_applied.emit(type)
		return
	
	var tween := create_tween()
	for status: Status in status_queue:
		tween.tween_callback(status.apply_status.bind(status_owner))
		tween.tween_interval(STATUS_APPLY_INTERVAL)
	
	tween.finished.connect(func(): statuses_applied.emit(type))


func add_status(status: Status) -> void:
	var stackable := status.stack_type != Status.StackType.NONE
	
	# Add it if it's new
	if not _has_status(status.id):
		var new_status_ui := STATUS_UI.instantiate() as StatusUI
		add_child(new_status_ui)
		new_status_ui.mouse_entered.connect(_on_status_ui_mouse_entered.bind(new_status_ui))
		new_status_ui.mouse_exited.connect(_on_status_ui_mouse_exited)
		new_status_ui.status = status
		new_status_ui.status.status_applied.connect(_on_status_applied)
		new_status_ui.status.initialize_status(status_owner)
		_emit_player_hand_cost_context_if_needed()
		return

	# If it's unique and we already have it, we can return
	if not status.can_expire and not stackable:
		return
	
	# If it's duration-stackable, expand it
	if status.can_expire and status.stack_type == Status.StackType.DURATION:
		_get_status(status.id).duration += status.duration
		_emit_player_hand_cost_context_if_needed()
		return
	
	# If it's stackable, stack it
	if status.stack_type == Status.StackType.INTENSITY:
		_get_status(status.id).stacks += status.stacks
		_emit_player_hand_cost_context_if_needed()


func _emit_player_hand_cost_context_if_needed() -> void:
	if status_owner is Player:
		Events.player_hand_cost_context_changed.emit()

func _has_status(id: String) -> bool:
	for status_ui: StatusUI in get_children():
		if status_ui.status.id == id:
			return true
			
	return false


func _get_status(id: String) -> Status:
	for status_ui: StatusUI in get_children():
		if status_ui.status.id == id:
			return status_ui.status
	
	return null


func get_status_by_id(status_id: String) -> Status:
	return _get_status(status_id)


func _get_all_statuses() -> Array[Status]:
	var statuses: Array[Status] = []
	for status_ui: StatusUI in get_children():
		statuses.append(status_ui.status)
		
	return statuses


func _on_status_applied(status: Status) -> void:
	if status.can_expire:
		status.duration -= 1


func _on_status_ui_mouse_entered(ui: StatusUI) -> void:
	if ui.status:
		# 显示状态 tooltip 前，先关闭卡牌关键词 tooltip
		Events.card_keyword_tooltip_hide.emit()
		Events.status_tooltip_hover_show.emit(ui.status, ui, tooltips_open_to_right)


func _on_status_ui_mouse_exited() -> void:
	# 立即检查鼠标是否仍在其他状态图标上，不要延迟
	var mp := get_global_mouse_position()
	for c in get_children():
		if c is StatusUI and (c as StatusUI).get_global_rect().has_point(mp):
			return
	# 如果鼠标不在任何状态图标上，立即隐藏 tooltip
	Events.status_tooltip_hover_hide.emit()
