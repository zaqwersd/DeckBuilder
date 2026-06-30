@tool
class_name StatusHandler
extends VBoxContainer

signal statuses_applied(type: Status.Type)

const STATUS_APPLY_INTERVAL := 0.25
const STATUS_UI = preload("res://scenes/status_handler/status_ui.tscn")
const DEFAULT_ICON_SEPARATION := 8
const ICON_CELL_SIZE := 33
const STATUS_POPUP_PLAYER_ABOVE_BAR_PX := 200.0
const STATUS_POPUP_FLOAT_RISE_PX := 42.0

@export var status_owner: Node2D
## 由 StatusBar 设置：玩家 true（说明在右），敌人 false（说明在左）
var tooltips_open_to_right: bool = true

var _active_status_hover_ui: StatusUI = null
var _row_boxes: Array[HBoxContainer] = []
var _relayout_queued := false
var _status_popup_values: Dictionary = {}


func _battle_events() -> Node:
	if Engine.is_editor_hint() or not is_inside_tree():
		return null
	var events := get_tree().root.get_node_or_null("Events")
	if events == null or not events.has_method("is_combat_ended"):
		return null
	return events


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	alignment = BoxContainer.ALIGNMENT_BEGIN
	_ensure_row_count(1)
	if not child_exiting_tree.is_connected(_on_child_exiting_tree):
		child_exiting_tree.connect(_on_child_exiting_tree)
	if Engine.is_editor_hint():
		set_process(false)
		return
	set_process(true)
	var events := _battle_events()
	if events != null and events.has_signal("combat_flow_reset"):
		if not events.combat_flow_reset.is_connected(_on_combat_flow_reset):
			events.combat_flow_reset.connect(_on_combat_flow_reset)
	call_deferred("_queue_relayout")


func _exit_tree() -> void:
	set_process(false)
	_clear_status_hover_if_active()


func _on_combat_flow_reset() -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	set_process(true)


func _on_child_exiting_tree(node: Node) -> void:
	if node is StatusUI:
		_queue_relayout()


func _ensure_row_count(count: int) -> void:
	while _row_boxes.size() < count:
		var row := HBoxContainer.new()
		row.name = "StatusRow%d" % _row_boxes.size()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.alignment = BoxContainer.ALIGNMENT_BEGIN
		row.add_theme_constant_override("separation", DEFAULT_ICON_SEPARATION)
		add_child(row)
		_row_boxes.append(row)


func _each_status_ui() -> Array[StatusUI]:
	var out: Array[StatusUI] = []
	for row in _row_boxes:
		for child in row.get_children():
			if child is StatusUI and _is_live_status_ui(child as StatusUI):
				out.append(child as StatusUI)
	for child in get_children():
		if child is HBoxContainer:
			continue
		if child is StatusUI and _is_live_status_ui(child as StatusUI):
			out.append(child as StatusUI)
	return out


func _row_width(icon_count: int, separation: int) -> int:
	if icon_count <= 0:
		return 0
	return icon_count * ICON_CELL_SIZE + maxi(0, icon_count - 1) * separation


func _max_icons_in_row(max_width: int, separation: int) -> int:
	if max_width <= 0:
		return 9999
	var max_n := 0
	for n in range(1, 64):
		if _row_width(n, separation) <= max_width:
			max_n = n
		else:
			break
	return max_n


func _split_icon_counts(total: int, max_width: int, separation: int) -> PackedInt32Array:
	var per_row := _max_icons_in_row(max_width, separation)
	if per_row <= 0:
		per_row = 1
	var counts := PackedInt32Array()
	var remaining := total
	while remaining > 0:
		var take := mini(remaining, per_row)
		counts.append(take)
		remaining -= take
	return counts


func _row_alignment(row_index: int, serpentine: bool) -> BoxContainer.AlignmentMode:
	if not serpentine or row_index % 2 == 0:
		return BoxContainer.ALIGNMENT_BEGIN
	return BoxContainer.ALIGNMENT_END


func _plan_row_layout(icon_count: int, max_width: int) -> Dictionary:
	if max_width <= 0:
		return {
			"row_counts": PackedInt32Array([icon_count]),
			"row_separation": DEFAULT_ICON_SEPARATION,
			"serpentine": false,
		}
	for sep in range(DEFAULT_ICON_SEPARATION, -1, -1):
		if _row_width(icon_count, sep) <= max_width:
			return {
				"row_counts": PackedInt32Array([icon_count]),
				"row_separation": sep,
				"serpentine": false,
			}
	# 间距已为 0 仍超宽：先保持单行溢出；再多 1 个状态才开始换行。
	var per_row_zero := _max_icons_in_row(max_width, 0)
	if icon_count <= per_row_zero + 1:
		return {
			"row_counts": PackedInt32Array([icon_count]),
			"row_separation": 0,
			"serpentine": false,
		}
	return {
		"row_counts": _split_icon_counts(icon_count, max_width, 0),
		"row_separation": 0,
		"serpentine": true,
	}


func _get_minimum_size() -> Vector2:
	var ms := super.get_minimum_size()
	# 状态栏只贡献高度，横向宽度由 StatusBar / 血条决定，避免撑宽血条。
	ms.x = 0.0
	return ms


func _queue_relayout() -> void:
	if _relayout_queued:
		return
	_relayout_queued = true
	call_deferred("_deferred_relayout")


func _deferred_relayout() -> void:
	_relayout_queued = false
	if not is_inside_tree():
		return
	var bar_w := 0
	var parent_bar := get_parent()
	if parent_bar is StatusBar and parent_bar.has_method("get_health_bar_layout_width"):
		bar_w = parent_bar.get_health_bar_layout_width()
	relayout_to_width(bar_w)


## 在血条宽度内排布状态：先缩小间距；间距为 0 仍超宽时先单行溢出，再多 1 个才换行（蛇形）。
func relayout_to_width(max_width: int) -> void:
	var icons := _each_status_ui()
	var icon_count := icons.size()
	if icon_count == 0:
		for row in _row_boxes:
			row.hide()
		custom_minimum_size = Vector2.ZERO
		return

	var plan := _plan_row_layout(icon_count, max_width)
	var row_counts: PackedInt32Array = plan["row_counts"]
	var row_separation: int = plan["row_separation"]
	var serpentine: bool = plan["serpentine"]
	_ensure_row_count(row_counts.size())
	var icon_index := 0
	for row_index in range(_row_boxes.size()):
		var row := _row_boxes[row_index]
		if row_index >= row_counts.size():
			for child in row.get_children().duplicate():
				if child is StatusUI:
					row.remove_child(child)
			row.hide()
			continue
		var take: int = row_counts[row_index]
		row.add_theme_constant_override("separation", row_separation)
		row.alignment = _row_alignment(row_index, serpentine)
		row.show()
		for child in row.get_children().duplicate():
			if child is StatusUI:
				row.remove_child(child)
		for _i in range(take):
			row.add_child(icons[icon_index])
			icon_index += 1

	var row_gap := maxi(0, row_counts.size() - 1) * int(get_theme_constant("separation"))
	custom_minimum_size = Vector2(
		0.0,
		float(row_counts.size() * ICON_CELL_SIZE + row_gap)
	)
	queue_sort()


func _process(_delta: float) -> void:
	var events := _battle_events()
	if events == null:
		return
	if events.is_combat_ended():
		_clear_status_hover_if_active()
		set_process(false)
		return
	var viewport := get_viewport()
	var screen_pos := CombatPointer.screen_mouse(viewport)
	var hovered: StatusUI = null
	for ui: StatusUI in _each_status_ui():
		var hit_ctl := _status_ui_hit_control(ui)
		if not CombatPointer.control_has_screen_point(hit_ctl, screen_pos, 4.0):
			continue
		# 仅在有模态独占层时跳过；勿把同层 BattleUI 当成遮挡（否则战斗状态栏永远无 tooltip）
		if events.get_pointer_exclusive_leaf() != null and events.is_pointer_ui_obscured_for(ui):
			continue
		hovered = ui
		break
	if hovered != null and hovered.status != null:
		if _active_status_hover_ui != hovered:
			# 勿 emit card_keyword_tooltip_hide：会取消 Run 上 game_tooltip 的 show 协程（_layout_generation++）
			events.status_tooltip_hover_show.emit(hovered.status, hovered, tooltips_open_to_right)
			_active_status_hover_ui = hovered
	elif _active_status_hover_ui != null:
		_clear_status_hover_if_active()


func _clear_status_hover_if_active() -> void:
	if _active_status_hover_ui == null:
		return
	_active_status_hover_ui = null
	var events := _battle_events()
	if events != null:
		events.status_tooltip_hover_hide.emit()


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

	var events := _battle_events()
	if events == null or events.is_combat_ended() or status_queue.size() == 1:
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
	if _try_block_with_artifact(status):
		return

	var stackable := status.stack_type != Status.StackType.NONE
	if status.allow_multiple_instances:
		_add_new_status_ui(status)
		return
	
	# Add it if it's new
	if not _has_status(status.id):
		_add_new_status_ui(status)
		return

	if status.id == "next_turn_mana" and _has_status("next_turn_mana"):
		var existing_mana := _get_status("next_turn_mana") as NextTurnManaStatus
		var incoming_mana := status as NextTurnManaStatus
		if existing_mana and incoming_mana:
			existing_mana.mana_to_grant += incoming_mana.mana_to_grant
			existing_mana.status_changed.emit()
		_emit_player_hand_cost_context_if_needed()
		_request_enemy_intent_refresh()
		return

	if status.id == "malice_state" and _has_status("malice_state"):
		var existing_malice := _get_status("malice_state") as MaliceStatus
		var incoming_malice := status as MaliceStatus
		if existing_malice and incoming_malice:
			existing_malice.m += incoming_malice.m
			existing_malice.status_changed.emit()
		_emit_player_hand_cost_context_if_needed()
		_request_enemy_intent_refresh()
		return

	# If it's unique and we already have it, we can return
	if not status.can_expire and not stackable:
		return
	
	# If it's duration-stackable, expand it
	if status.can_expire and status.stack_type == Status.StackType.DURATION:
		var existing := _get_status(status.id)
		_ensure_status_intent_refresh_connected(existing)
		existing.set_duration(existing.duration + status.duration)
		_emit_player_hand_cost_context_if_needed()
		_request_enemy_intent_refresh()
		return
	
	# If it's stackable, stack it
	if status.stack_type == Status.StackType.INTENSITY:
		var existing_intensity := _get_status(status.id)
		_ensure_status_intent_refresh_connected(existing_intensity)
		existing_intensity.set_stacks(existing_intensity.stacks + status.stacks)
		if not existing_intensity.awaits_turn_start:
			existing_intensity.initialize_status(status_owner)
		_emit_player_hand_cost_context_if_needed()
		_request_enemy_intent_refresh()

func _add_new_status_ui(status: Status) -> void:
	var new_status_ui := STATUS_UI.instantiate() as StatusUI
	new_status_ui.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	new_status_ui.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ensure_row_count(1)
	_row_boxes[0].add_child(new_status_ui)
	new_status_ui.status = status
	_track_status_popup_initial(status)
	_spawn_status_change_popup(status, _status_popup_amount(status), true)
	new_status_ui.status.status_applied.connect(_on_status_applied)
	if not new_status_ui.status.awaits_turn_start:
		new_status_ui.status.initialize_status(status_owner)
	_ensure_status_intent_refresh_connected(new_status_ui.status)
	_emit_player_hand_cost_context_if_needed()
	_request_enemy_intent_refresh()
	_queue_relayout()
func _try_block_with_artifact(status: Status) -> bool:
	if status == null or status.id == "artifact":
		return false
	if not _has_status("artifact"):
		return false
	if not is_harmful_status_for_purge(status):
		return false
	var artifact := _get_status("artifact") as ArtifactStatus
	if artifact == null or artifact.stacks <= 0:
		return false
	artifact.consume_one()
	return true


func _emit_player_hand_cost_context_if_needed() -> void:
	if status_owner is Player:
		var events := _battle_events()
		if events == null:
			return
		events.player_hand_cost_context_changed.emit()
		_emit_player_combat_stat_context_if_needed()

func _is_live_status_ui(status_ui: StatusUI) -> bool:
	return status_ui != null and not status_ui.is_queued_for_deletion()


func _has_status(id: String) -> bool:
	for status_ui: StatusUI in _each_status_ui():
		if status_ui.status.id == id:
			return true
	return false


func _get_status(id: String) -> Status:
	for status_ui: StatusUI in _each_status_ui():
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
	var uis: Array[StatusUI] = []
	for status_ui: StatusUI in _each_status_ui():
		if status_ui.status != null and is_harmful_status_for_purge(status_ui.status):
			uis.append(status_ui)
	if uis.is_empty():
		return
	for status_ui in uis:
		var st := status_ui.status
		status_ui.free()
		st.deactivate_status(status_owner)
	if status_owner is Player:
		sync_combat_modifiers_with_statuses()
		var events := _battle_events()
		if events != null and not events.is_player_turn_start_resolving() and not events.is_player_turn_end_resolving():
			events.player_combat_stat_context_changed.emit()
	_emit_player_hand_cost_context_if_needed()
	_request_enemy_intent_refresh()
	_queue_relayout()


func remove_status_by_id(status_id: String) -> void:
	for status_ui: StatusUI in _each_status_ui():
		if status_ui.status == null or status_ui.status.id != status_id:
			continue
		var st := status_ui.status
		status_ui.free()
		st.deactivate_status(status_owner)
		if status_owner is Player:
			sync_combat_modifiers_with_statuses()
			var events := _battle_events()
			if events != null and not events.is_player_turn_start_resolving() and not events.is_player_turn_end_resolving():
				events.player_combat_stat_context_changed.emit()
		_emit_player_hand_cost_context_if_needed()
		_request_enemy_intent_refresh()
		_queue_relayout()
		return


func _emit_player_combat_stat_context_if_needed() -> void:
	if status_owner is Player:
		var events := _battle_events()
		if events == null or events.is_player_turn_start_resolving() or events.is_player_turn_end_resolving():
			return
		events.player_combat_stat_context_changed.emit()


func _get_all_statuses() -> Array[Status]:
	var statuses: Array[Status] = []
	for status_ui: StatusUI in _each_status_ui():
		statuses.append(status_ui.status)
	return statuses


func activate_awaiting_statuses() -> void:
	if not status_owner is Player:
		return
	for status_ui: StatusUI in _each_status_ui():
		var st := status_ui.status
		if st == null or not st.awaits_turn_start:
			continue
		st.awaits_turn_start = false
		st.skip_next_start_of_turn_tick = true
		st.initialize_status(status_owner)
		st.status_changed.emit()
		_request_enemy_intent_refresh()


## 玩家回合开始、揭示意图前：扣敌人身上易伤/虚弱等 duration debuff 的一回合。
func apply_enemy_debuff_ticks_at_player_turn_start() -> void:
	if status_owner is Player:
		return
	for status: Status in _get_all_statuses():
		if not status.ticks_on_player_turn_start_on_enemy or status.awaits_turn_start:
			continue
		status.apply_status(status_owner)


## 回合开始 tick 后、显示敌人意图前：以状态栏为准同步修饰器（含清除残留易伤）。
func prepare_combat_context_for_intent() -> void:
	sync_combat_modifiers_with_statuses()


## 状态栏 ↔ 修饰器对齐；意图伤害与实际伤害共用同一套判定。
func sync_combat_modifiers_with_statuses() -> void:
	if not status_owner is Player:
		return
	var player := status_owner as Player
	for status_ui: StatusUI in _each_status_ui():
		var st := status_ui.status
		if st == null:
			continue
		if st.can_expire and st.duration <= 0:
			st.deactivate_status(status_owner)
			continue
		if st.awaits_turn_start:
			continue
		st.initialize_status(status_owner)
	VulnerableStatus.sync_modifier_with_status(player)


func _on_status_applied(status: Status) -> void:
	if status.skip_next_start_of_turn_tick:
		status.skip_next_start_of_turn_tick = false
		return
	if status.can_expire:
		status.set_duration(status.duration - 1)
		if status.duration <= 0:
			status.deactivate_status(status_owner)
	_request_enemy_intent_refresh()


func _status_popup_amount(status: Status) -> int:
	if status == null:
		return 0
	if status.stack_type == Status.StackType.INTENSITY:
		return status.stacks
	if status.stack_type == Status.StackType.DURATION:
		return status.duration
	return 1


func _track_status_popup_initial(status: Status) -> void:
	if status == null:
		return
	_status_popup_values[status.get_instance_id()] = _status_popup_amount(status)
	if not status.status_changed.is_connected(_on_status_changed_for_popup.bind(status)):
		status.status_changed.connect(_on_status_changed_for_popup.bind(status))


func _on_status_changed_for_popup(status: Status) -> void:
	if status == null:
		return
	var key := status.get_instance_id()
	var before := int(_status_popup_values.get(key, 0))
	var now := _status_popup_amount(status)
	_status_popup_values[key] = now
	var delta := now - before
	if delta != 0:
		_spawn_status_change_popup(status, abs(delta), delta > 0)
	if (status.can_expire and status.duration <= 0) or (status.stack_type == Status.StackType.INTENSITY and status.stacks == 0):
		_spawn_status_end_popup(status)
		_status_popup_values.erase(key)


func _is_status_change_good(status: Status, increased: bool) -> bool:
	if status == null:
		return increased
	if status.polarity == Status.Polarity.NEGATIVE:
		return not increased
	return increased


func _spawn_status_change_popup(status: Status, amount: int, increased: bool) -> void:
	if amount <= 0 or status_owner == null or not is_instance_valid(status_owner) or not status_owner.is_inside_tree():
		return
	var sign := "+" if increased else "-"
	var text := "%s%d %s" % [sign, amount, status.get_display_name()]
	var good := _is_status_change_good(status, increased)
	_spawn_status_popup_text(text, Color(0.36, 1.0, 0.48, 1.0) if good else Color(1.0, 0.28, 0.24, 1.0))


func _spawn_status_end_popup(status: Status) -> void:
	if status == null or status_owner == null or not is_instance_valid(status_owner) or not status_owner.is_inside_tree():
		return
	_spawn_status_popup_text("%s 效果结束" % status.get_display_name(), Color(0.92, 0.92, 0.92, 1.0))


func _get_health_bar_global_rect() -> Rect2:
	var parent_bar := get_parent()
	if parent_bar != null:
		var health_row := parent_bar.get_node_or_null("HealthRow") as Control
		if health_row != null and health_row.is_inside_tree():
			return health_row.get_global_rect()
	if status_owner is Node2D and (status_owner as Node2D).is_inside_tree():
		var anchor := (status_owner as Node2D).global_position
		return Rect2(anchor + Vector2(-40.0, -82.0), Vector2(80.0, 10.0))
	return Rect2()


func _get_enemy_hitbox_global_center() -> Vector2:
	if status_owner is Enemy:
		var enemy := status_owner as Enemy
		if is_instance_valid(enemy.collision_shape_2d):
			return enemy.collision_shape_2d.global_position
	if status_owner is Node2D and (status_owner as Node2D).is_inside_tree():
		return (status_owner as Node2D).global_position
	return Vector2.ZERO


func _resolve_status_popup_anchor() -> Dictionary:
	if status_owner is Player:
		var bar_rect := _get_health_bar_global_rect()
		return {
			"point": Vector2(bar_rect.get_center().x, bar_rect.position.y - STATUS_POPUP_PLAYER_ABOVE_BAR_PX),
			"center_label": false,
		}
	if status_owner is Enemy:
		return {
			"point": _get_enemy_hitbox_global_center(),
			"center_label": true,
		}
	var fallback_rect := _get_health_bar_global_rect()
	return {
		"point": Vector2(fallback_rect.get_center().x, fallback_rect.position.y - 72.0),
		"center_label": false,
	}


func _spawn_status_popup_text(text: String, color: Color) -> void:
	var host := status_owner.get_parent()
	if host == null:
		host = status_owner.get_tree().current_scene
	if host == null:
		return
	var label := Label.new()
	label.text = text
	label.z_index = 900
	label.z_as_relative = false
	label.modulate = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	host.add_child(label)
	var anchor := _resolve_status_popup_anchor()
	_run_status_popup_animation(label, anchor["point"], anchor["center_label"])


func _run_status_popup_animation(label: Label, anchor: Vector2, center_label: bool) -> void:
	await label.get_tree().process_frame
	if not is_instance_valid(label):
		return
	label.reset_size()
	var sz := label.get_minimum_size()
	var start := anchor - sz * 0.5 if center_label else Vector2(anchor.x - sz.x * 0.5, anchor.y)
	label.global_position = start
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "global_position", start + Vector2(0.0, -STATUS_POPUP_FLOAT_RISE_PX), 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.75)
	tween.finished.connect(label.queue_free)


func _ensure_status_intent_refresh_connected(status: Status) -> void:
	if status == null:
		return
	if not status.status_changed.is_connected(_on_status_changed_for_intent_refresh):
		status.status_changed.connect(_on_status_changed_for_intent_refresh)


func _on_status_changed_for_intent_refresh() -> void:
	_request_enemy_intent_refresh()


## 玩家/敌人状态影响意图伤害或玩家承伤时，刷新全部敌人意图（及玩家手牌战斗数字）。
func _request_enemy_intent_refresh() -> void:
	var events := _battle_events()
	if events == null or events.is_combat_ended() or events.is_player_turn_start_resolving() or events.is_player_turn_end_resolving():
		return
	if not is_inside_tree():
		return
	events.player_combat_stat_context_changed.emit()
