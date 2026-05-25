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
			return status.type == type and not status.awaits_turn_start
	)
	if status_queue.is_empty():
		statuses_applied.emit(type)
		return
	
	if Events.is_combat_ended() or status_queue.size() == 1:
		for status: Status in status_queue:
			status.apply_status(status_owner)
		statuses_applied.emit(type)
		return
	
	var tween := create_tween()
	for status: Status in status_queue:
		tween.tween_callback(status.apply_status.bind(status_owner))
		tween.tween_interval(STATUS_APPLY_INTERVAL)
	
	tween.finished.connect(_on_status_apply_tween_finished.bind(type), CONNECT_ONE_SHOT)


func _on_status_apply_tween_finished(type: Status.Type) -> void:
	if not is_inside_tree():
		return
	statuses_applied.emit(type)


func add_status(status: Status) -> void:
	var stackable := status.stack_type != Status.StackType.NONE
	
	# Add it if it's new
	if not _has_status(status.id):
		var new_status_ui := STATUS_UI.instantiate() as StatusUI
		new_status_ui.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		new_status_ui.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(new_status_ui)
		new_status_ui.mouse_entered.connect(_on_status_ui_mouse_entered.bind(new_status_ui))
		new_status_ui.mouse_exited.connect(_on_status_ui_mouse_exited)
		new_status_ui.status = status
		new_status_ui.status.status_applied.connect(_on_status_applied)
		if not new_status_ui.status.awaits_turn_start:
			new_status_ui.status.initialize_status(status_owner)
		_emit_player_hand_cost_context_if_needed()
		return

	if status.id == "next_turn_mana" and _has_status("next_turn_mana"):
		var existing_mana := _get_status("next_turn_mana") as NextTurnManaStatus
		var incoming_mana := status as NextTurnManaStatus
		if existing_mana and incoming_mana:
			existing_mana.mana_to_grant += incoming_mana.mana_to_grant
			existing_mana.status_changed.emit()
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


func remove_status_by_id(status_id: String) -> void:
	for status_ui: StatusUI in get_children():
		if status_ui.status == null or status_ui.status.id != status_id:
			continue
		if status_ui.status.has_method("deactivate_status"):
			status_ui.status.deactivate_status(status_owner)
		status_ui.queue_free()
		_emit_player_hand_cost_context_if_needed()
		return


func _get_all_statuses() -> Array[Status]:
	var statuses: Array[Status] = []
	for status_ui: StatusUI in get_children():
		statuses.append(status_ui.status)
		
	return statuses


func activate_awaiting_statuses() -> void:
	if not status_owner is Player:
		return
	for status_ui: StatusUI in get_children():
		var st := status_ui.status
		if st == null or not st.awaits_turn_start:
			continue
		st.awaits_turn_start = false
		st.skip_next_start_of_turn_tick = true
		st.initialize_status(status_owner)
		st.status_changed.emit()


func _on_status_applied(status: Status) -> void:
	if status.skip_next_start_of_turn_tick:
		status.skip_next_start_of_turn_tick = false
		return
	if status.can_expire:
		status.duration -= 1


func _on_status_ui_mouse_entered(ui: StatusUI) -> void:
	if ui.status:
		# 显示状态 tooltip 前，先关闭卡牌关键词 tooltip
		Events.card_keyword_tooltip_hide.emit()
		Events.status_tooltip_hover_show.emit(ui.status, ui, tooltips_open_to_right)


func _on_status_ui_mouse_exited() -> void:
	# 延迟一帧再判：相邻图标间移动时 exit 可能早于 enter
	call_deferred("_deferred_status_ui_mouse_hide_check")


func _deferred_status_ui_mouse_hide_check() -> void:
	if not is_inside_tree():
		return
	var mp := get_global_mouse_position()
	for c in get_children():
		if c is StatusUI and (c as StatusUI).get_global_rect().has_point(mp):
			return
	Events.status_tooltip_hover_hide.emit()
