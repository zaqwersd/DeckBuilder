class_name StatusHandler
extends HBoxContainer

signal statuses_applied(type: Status.Type)

const STATUS_APPLY_INTERVAL := 0.25
const STATUS_UI = preload("res://scenes/status_handler/status_ui.tscn")

@export var status_owner: Node2D
## 由 StatusBar 设置：玩家 true（说明在右），敌人 false（说明在左）
var tooltips_open_to_right: bool = true

var _active_status_hover_ui: StatusUI = null


func _ready() -> void:
	set_process(true)


func _process(_delta: float) -> void:
	if Events.is_combat_ended():
		_clear_status_hover_if_active()
		return
	var viewport := get_viewport()
	var screen_pos := CombatPointer.screen_mouse(viewport)
	var hovered: StatusUI = null
	for c in get_children():
		if not c is StatusUI:
			continue
		var ui := c as StatusUI
		var hit_ctl := _status_ui_hit_control(ui)
		if not CombatPointer.control_has_screen_point(hit_ctl, screen_pos, 4.0):
			continue
		# 仅在有模态独占层时跳过；勿把同层 BattleUI 当成遮挡（否则战斗状态栏永远无 tooltip）
		if Events.get_pointer_exclusive_leaf() != null and Events.is_pointer_ui_obscured_for(ui):
			continue
		hovered = ui
		break
	if hovered != null and hovered.status != null:
		if _active_status_hover_ui != hovered:
			# 勿 emit card_keyword_tooltip_hide：会取消 Run 上 game_tooltip 的 show 协程（_layout_generation++）
			Events.status_tooltip_hover_show.emit(hovered.status, hovered, tooltips_open_to_right)
			_active_status_hover_ui = hovered
	elif _active_status_hover_ui != null:
		_clear_status_hover_if_active()


func _clear_status_hover_if_active() -> void:
	if _active_status_hover_ui == null:
		return
	_active_status_hover_ui = null
	Events.status_tooltip_hover_hide.emit()


func is_pointer_over_status_ui(ui: StatusUI) -> bool:
	if ui == null or not is_instance_valid(ui):
		return false
	var viewport := get_viewport()
	if viewport == null:
		return false
	var screen_pos := CombatPointer.screen_mouse(viewport)
	return CombatPointer.control_has_screen_point(_status_ui_hit_control(ui), screen_pos, 4.0)


static func _status_ui_hit_control(ui: StatusUI) -> Control:
	if ui == null:
		return ui
	var icon := ui.get_node_or_null("Icon") as Control
	if is_instance_valid(icon):
		return icon
	return ui


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
		var existing := _get_status(status.id)
		existing.set_duration(existing.duration + status.duration)
		_emit_player_hand_cost_context_if_needed()
		return
	
	# If it's stackable, stack it
	if status.stack_type == Status.StackType.INTENSITY:
		var existing_intensity := _get_status(status.id)
		existing_intensity.set_stacks(existing_intensity.stacks + status.stacks)
		if not existing_intensity.awaits_turn_start:
			existing_intensity.initialize_status(status_owner)
		_emit_player_hand_cost_context_if_needed()


func _emit_player_hand_cost_context_if_needed() -> void:
	if status_owner is Player:
		Events.player_hand_cost_context_changed.emit()
		_emit_player_combat_stat_context_if_needed()

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


## 牛奶等：移除负面极性状态、临时力量，以及层数为负的力量/敏捷等。
func is_harmful_status_for_purge(status: Status) -> bool:
	if status == null:
		return false
	if status.polarity == Status.Polarity.NEGATIVE:
		return true
	if status.id == "temp_strength":
		return true
	if status.stack_type == Status.StackType.INTENSITY:
		return status.counter_shows_as_harmful(status.stacks)
	return false


func remove_harmful_statuses() -> void:
	var ids: Array[String] = []
	for status_ui: StatusUI in get_children():
		if status_ui.status != null and is_harmful_status_for_purge(status_ui.status):
			ids.append(status_ui.status.id)
	for status_id: String in ids:
		remove_status_by_id(status_id)


func remove_status_by_id(status_id: String) -> void:
	for status_ui: StatusUI in get_children():
		if status_ui.status == null or status_ui.status.id != status_id:
			continue
		status_ui.status.deactivate_status(status_owner)
		status_ui.queue_free()
		_emit_player_hand_cost_context_if_needed()
		return


func _emit_player_combat_stat_context_if_needed() -> void:
	if status_owner is Player:
		if Events.is_player_turn_start_resolving():
			return
		Events.player_combat_stat_context_changed.emit()


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


## 回合开始 tick 后、显示敌人意图前：以状态栏为准同步修饰器（含清除残留易伤）。
func prepare_combat_context_for_intent() -> void:
	sync_combat_modifiers_with_statuses()


## 状态栏 ↔ 修饰器对齐；意图伤害与实际伤害共用同一套判定。
func sync_combat_modifiers_with_statuses() -> void:
	if not status_owner is Player:
		return
	var player := status_owner as Player
	for status_ui: StatusUI in get_children():
		var st := status_ui.status
		if st == null:
			continue
		if st.can_expire and st.duration <= 0:
			st.deactivate_status(status_owner)
			continue
		if st.awaits_turn_start:
			continue
		st.initialize_status(status_owner)
	ExposedStatus.sync_modifier_with_status(player)


func _on_status_applied(status: Status) -> void:
	if status.skip_next_start_of_turn_tick:
		status.skip_next_start_of_turn_tick = false
		return
	if status.can_expire:
		status.set_duration(status.duration - 1)
		if status.duration <= 0:
			status.deactivate_status(status_owner)

