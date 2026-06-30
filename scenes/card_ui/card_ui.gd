class_name CardUI
extends Control

## 手牌自选层：存在时优先消费点击，阻止进入拖拽/打出状态机
const HAND_PICK_DELEGATE_META := &"hand_pick_delegate"

## 手牌内鼠标悬停时卡牌上移的像素
const HAND_HOVER_LIFT_PX := 180.0
## 抬起后交互命中区随视觉上移的比例（仅部分跟随，避免命中框完全跟上造成抖动）
const HAND_HOVER_PICK_LIFT_FOLLOW := 0.35
const HAND_HOVER_Z := 10
## 拾起/瞄准中的牌须高于手牌槽悬停层（Hand.HAND_SLOT_HOVER_Z = 500）
const PICKED_CARD_Z_INDEX := 520

signal reparent_requested(which_card_ui: CardUI)

const BASE_STYLEBOX := preload("res://scenes/card_ui/card_base_stylebox.tres")
const DRAG_STYLEBOX := preload("res://scenes/card_ui/card_drag_stylebox.tres")
const HOVER_STYLEBOX := preload("res://scenes/card_ui/card_hover_stylebox.tres")

@export var player_modifiers: ModifierHandler
@export var card: Card : set = _set_card
@export var char_stats: CharacterStats : set = _set_char_stats

@onready var card_visuals: CardVisualsBase = $CardVisuals
@onready var drop_point_detector: Area2D = $CardVisuals/DropPointDetector
@onready var card_state_machine: CardStateMachine = $CardStateMachine
@onready var targets: Array[Node] = []

var combat_player: Player
var original_index := 0
var parent: Control
var tween: Tween
## 手牌悬停抬起动画（0.1s 二态切换）
var _hover_lift_tween: Tween
## 由 Hand.add_card 写入：卡牌所属手牌槽，用于悬停位移与回手排序（避免 HBox 每帧盖写 position）
var hand_slot: Control
var playable := true : set = _set_playable
var disabled := true
## 由 `sync_hand_hover_presentation` 维护
var _hand_hover_visual_active := false
var _hover_lift_target_y := 0.0
var _hand_hover_target_visual_y := 0.0


func _ready() -> void:
	Events.card_aim_started.connect(_on_other_card_aim_started)
	Events.card_drag_started.connect(_on_other_card_drag_started)
	Events.card_drag_ended.connect(_on_card_drag_or_aim_ended)
	Events.card_aim_ended.connect(_on_card_drag_or_aim_ended)
	card_state_machine.init(self)
	if is_instance_valid(card_visuals):
		card_visuals.mouse_filter = Control.MOUSE_FILTER_STOP
		if not card_visuals.gui_input.is_connected(_on_card_visuals_gui_input):
			card_visuals.gui_input.connect(_on_card_visuals_gui_input)
		card_visuals.number_bbcode_style = Card.NumberBbcodeStyle.COMBAT_PILES_AND_HAND
	if is_instance_valid(drop_point_detector):
		drop_point_detector.input_pickable = true
		if not drop_point_detector.input_event.is_connected(_on_drop_point_detector_input_event):
			drop_point_detector.input_event.connect(_on_drop_point_detector_input_event)


func _on_card_visuals_gui_input(event: InputEvent) -> void:
	if Events.is_pointer_ui_obscured_for(self):
		return
	_on_gui_input(event)


## Area2D 鼠标进入回调（由 CardVisualsBase 调用）
func _on_card_visuals_mouse_entered() -> void:
	if Events.is_pointer_ui_obscured_for(self):
		return
	card_state_machine.on_mouse_entered()


## Area2D 鼠标离开回调（由 CardVisualsBase 调用）
func _on_card_visuals_mouse_exited() -> void:
	if Events.is_pointer_ui_obscured_for(self):
		return
	card_state_machine.on_mouse_exited()


## Area2D 点击回调（由 CardVisualsBase 调用）
func _on_card_visuals_clicked() -> void:
	if Events.is_pointer_ui_obscured_for(self):
		return
	if not _is_hand_interaction_foremost():
		return
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	_on_gui_input(ev)


func _on_drop_point_detector_input_event(
	_viewport: Node,
	event: InputEvent,
	_shape_idx: int
) -> void:
	if Events.is_pointer_ui_obscured_for(self):
		return
	if not _is_hand_interaction_foremost():
		return
	if event is InputEventMouseButton:
		_on_gui_input(event)


func is_hand_hover_visual_active() -> bool:
	return _hand_hover_visual_active


func _is_hand_interaction_foremost() -> bool:
	if not is_instance_valid(hand_slot) or get_parent() != hand_slot:
		return true
	var hp := hand_slot.get_parent()
	if not (hp is Hand):
		return true
	return (hp as Hand).get_mouse_foremost_hand_card() == self


func is_in_hand_combat_layout() -> bool:
	if has_meta(HAND_PICK_DELEGATE_META):
		return false
	if not is_instance_valid(hand_slot) or get_parent() != hand_slot:
		return false
	return hand_slot.get_parent() is Hand


func forward_hand_gui_input(event: InputEvent) -> void:
	_on_gui_input(event)


func _input(event: InputEvent) -> void:
	if Events.is_pointer_ui_obscured_for(self):
		return
	if _is_in_dragging_state():
		card_state_machine.on_input(event)
		return
	card_state_machine.on_input(event)


func _unhandled_input(event: InputEvent) -> void:
	if Events.is_pointer_ui_obscured_for(self):
		return
	if not _is_in_dragging_state():
		return
	card_state_machine.on_input(event)


func _is_in_dragging_state() -> bool:
	var sm := card_state_machine
	if not sm or not sm.current_state:
		return false
	return sm.current_state.state == CardState.State.DRAGGING


func apply_picked_card_layer_order() -> void:
	z_index = PICKED_CARD_Z_INDEX
	z_as_relative = false
	var p := get_parent()
	if is_instance_valid(p):
		p.move_child(self, -1)


func animate_to_position(new_position: Vector2, duration: float) -> void:
	tween = create_tween().set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", new_position, duration)


func get_play_area_global_position() -> Vector2:
	var card_size := size
	if card_size.x <= 0.001 or card_size.y <= 0.001:
		card_size = _get_scaled_hit_size()
	var vp_size := get_viewport_rect().size
	var x := vp_size.x * 0.5 - card_size.x * 0.5
	var hand_ctrl := _resolve_combat_hand()
	if hand_ctrl != null:
		var hand_top := hand_ctrl.get_global_rect().position.y
		return Vector2(x, hand_top - card_size.y - 28.0)
	return Vector2(x, vp_size.y * 0.38 - card_size.y * 0.5)


func _resolve_combat_hand() -> Hand:
	if is_instance_valid(hand_slot):
		var hp := hand_slot.get_parent()
		if hp is Hand:
			return hp
	if not is_inside_tree():
		return null
	var ui_layer := get_tree().get_first_node_in_group("ui_layer")
	if ui_layer is BattleUI and is_instance_valid((ui_layer as BattleUI).hand):
		return (ui_layer as BattleUI).hand
	return null


func validate_and_fill_play_targets() -> bool:
	if not card or not char_stats:
		return false
	if not char_stats.can_play_card(card, get_effective_mana_cost(), combat_player):
		return false

	if card.is_single_targeted():
		_prune_invalid_targets()
		if targets.is_empty():
			return false
		if not (targets[0] is Enemy):
			return false
		return true

	if targets.is_empty():
		var tree := get_tree()
		if tree != null:
			for enemy in tree.get_nodes_in_group("enemies"):
				if is_instance_valid(enemy):
					targets.append(enemy)
		if targets.is_empty():
			return false
	return true


func is_mouse_in_hand_zone() -> bool:
	if not is_instance_valid(hand_slot):
		return false
	var hp := hand_slot.get_parent()
	if hp is Hand:
		return (hp as Hand).is_mouse_in_play_drag_hand_zone(get_global_mouse_position())
	return false


func _blocked_only_by_play_requirements() -> bool:
	if not card or not char_stats:
		return false
	return (
		card.allows_hand_drag_when_play_requirements_unmet()
		and not card.meets_play_requirements(char_stats)
	)


func allows_hand_drag_preview() -> bool:
	if not card or not char_stats:
		return false
	if card.is_unplayable():
		return true
	if _blocked_only_by_play_requirements():
		return true
	return card.type == Card.Type.STATUS and not char_stats.can_play_card(card, -1, combat_player)


func reset_hand_hover_lift_instant() -> void:
	_hand_hover_visual_active = false
	_hand_hover_target_visual_y = 0.0
	if _hover_lift_tween and _hover_lift_tween.is_running():
		_hover_lift_tween.kill()
		_hover_lift_tween = null
	if is_instance_valid(card_visuals):
		card_visuals.position.y = 0.0
	sync_hand_interaction_collision_from_layout()


## 禁用手牌等：收起抬起并恢复底板样式（不依赖状态机）。
func _restore_hand_slot_fan_rotation() -> void:
	if not is_instance_valid(hand_slot):
		return
	if hand_slot.has_meta(Hand.META_SLOT_FAN_ROTATION):
		hand_slot.rotation = hand_slot.get_meta(Hand.META_SLOT_FAN_ROTATION) as float


func force_hand_hover_visuals_off() -> void:
	z_index = 0
	z_as_relative = true
	if is_instance_valid(card_visuals):
		card_visuals.panel.set("theme_override_styles/panel", card_visuals.main_panel_style_base)
	reset_hand_hover_lift_instant()
	_restore_hand_slot_fan_rotation()
	_sync_hand_area_input_pickable(false)


## 手牌悬停：卡面仅在「正常(0)」与「抬起(-HAND_HOVER_LIFT_PX)」两档，用 0.1s tween 动画连接。
## 注意：CardVisuals 使用锚点布局，修改 offset 可能不可靠，改用 position.y 实现抬起效果。
func _tween_hand_hover_offset(target_y: float, duration: float = 0.1) -> void:
	if not is_instance_valid(card_visuals):
		return
	## 停止任何正在运行的动画
	if _hover_lift_tween and _hover_lift_tween.is_running():
		_hover_lift_tween.kill()
	_hover_lift_tween = null
	
	## 获取当前实际位置
	var current_y := card_visuals.position.y
	
	var is_current_valid := is_equal_approx(current_y, 0.0) or is_equal_approx(current_y, target_y)
	if not is_current_valid:
		card_visuals.position.y = 0.0
		current_y = 0.0
	
	## 如果当前值和目标值已经很接近，直接设置为目标值，不做动画
	if is_equal_approx(current_y, target_y):
		card_visuals.position.y = target_y
		return
	
	_hover_lift_tween = (
		create_tween()
		.set_trans(Tween.TRANS_QUAD)
		.set_ease(Tween.EASE_OUT)
	)
	_hover_lift_target_y = target_y
	_hover_lift_tween.tween_property(card_visuals, "position:y", target_y, duration)
	_hover_lift_tween.finished.connect(_on_hover_lift_tween_finished, CONNECT_ONE_SHOT)


func _on_hover_lift_tween_finished() -> void:
	if not is_instance_valid(card_visuals):
		return
	card_visuals.position.y = _hover_lift_target_y
	sync_hand_interaction_collision_from_layout()


func _exit_tree() -> void:
	if _hover_lift_tween and _hover_lift_tween.is_running():
		_hover_lift_tween.kill()
	_hover_lift_tween = null
	if tween and tween.is_running():
		tween.kill()
	tween = null


## 由 Hand 每帧调用：仅当牌在手牌槽且处于 BASE 时，根据鼠标几何决定是否抬起。
func sync_hand_hover_presentation() -> void:
	if disabled:
		if (
			_hand_hover_visual_active
			or _hand_hover_visual_offsets_not_snapped()
		):
			force_hand_hover_visuals_off()
		elif is_instance_valid(card_visuals):
			card_visuals.mouse_filter = Control.MOUSE_FILTER_STOP
		return
	if not is_instance_valid(hand_slot) or get_parent() != hand_slot:
		if _hand_hover_visual_active or _hand_hover_visual_offsets_not_snapped():
			force_hand_hover_visuals_off()
		elif is_instance_valid(card_visuals):
			card_visuals.mouse_filter = Control.MOUSE_FILTER_STOP
		return
	var sm := card_state_machine
	if not sm or not sm.current_state:
		return
	if sm.current_state.state != CardState.State.BASE:
		_set_hand_hover_visual_active(false)
		if is_instance_valid(card_visuals):
			card_visuals.mouse_filter = Control.MOUSE_FILTER_STOP
		return
	if is_in_hand_combat_layout():
		var is_foremost := _is_hand_interaction_foremost()
		var mp := get_global_mouse_position()
		var in_protrusion := is_global_point_in_hand_protrusion(mp)
		_sync_hand_area_input_pickable(is_foremost and not in_protrusion)
		_set_hand_hover_visual_active(is_foremost and not in_protrusion)
		return
	_apply_hand_visual_mouse_pick_filter()
	_set_hand_hover_visual_active(_is_hand_interaction_foremost())


func _hand_hover_visual_offsets_not_snapped() -> bool:
	if not is_instance_valid(card_visuals):
		return false
	if _hover_lift_tween and _hover_lift_tween.is_running():
		return true
	var y := card_visuals.position.y
	if is_equal_approx(y, 0.0):
		return false
	if is_equal_approx(y, _hand_hover_target_visual_y):
		return false
	return true


func _get_scaled_hit_size() -> Vector2:
	var hit_w := custom_minimum_size.x
	var hit_h := custom_minimum_size.y
	if hit_w <= 0.001 or hit_h <= 0.001:
		if is_instance_valid(hand_slot) and hand_slot.get_parent() is Hand:
			var s := (hand_slot.get_parent() as Hand).display_scale
			hit_w = roundf(Hand.CARD_UI_BASE_SIZE.x * s)
			hit_h = roundf(Hand.CARD_UI_BASE_SIZE.y * s)
		else:
			hit_w = Hand.CARD_UI_BASE_SIZE.x
			hit_h = Hand.CARD_UI_BASE_SIZE.y
	return Vector2(hit_w, hit_h)


## 卡面本体（210×220），用于抬起高度与 Voronoi 分牌，勿与点击命中框混用。
func _get_hand_face_local_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Hand.CARD_UI_BASE_SIZE)


## 点击命中：在本体基础上合并描述区等溢出子控件，不影响抬起动画计算。
func _get_hand_pick_local_rect() -> Rect2:
	var merged := _get_hand_face_local_rect()
	if not is_instance_valid(card_visuals):
		return merged
	if is_instance_valid(card_visuals.panel):
		merged = merged.merge((card_visuals.panel as Control).get_rect())
	if is_instance_valid(card_visuals.description_label):
		merged = merged.merge((card_visuals.description_label as Control).get_rect())
	var frame := card_visuals.get_node_or_null("%FramePanel") as Control
	if frame != null:
		merged = merged.merge(frame.get_rect())
	return merged


func _local_rect_to_global_quad(local_rect: Rect2, xf: Transform2D) -> PackedVector2Array:
	if not is_instance_valid(card_visuals) or not card_visuals.is_inside_tree():
		var gr := get_global_rect()
		return PackedVector2Array([
			gr.position,
			Vector2(gr.end.x, gr.position.y),
			gr.end,
			Vector2(gr.position.x, gr.end.y),
		])
	return PackedVector2Array([
		xf * local_rect.position,
		xf * Vector2(local_rect.end.x, local_rect.position.y),
		xf * local_rect.end,
		xf * Vector2(local_rect.position.x, local_rect.end.y),
	])


## 命中/抬起主判定：未抬起（position.y=0）时的变换。
func _card_visuals_global_transform_at_rest() -> Transform2D:
	if not is_instance_valid(card_visuals) or not card_visuals.is_inside_tree():
		return Transform2D.IDENTITY
	var xf := card_visuals.get_global_transform()
	var lift_y := card_visuals.position.y
	if absf(lift_y) > 0.001:
		xf.origin -= xf.y * lift_y
	return xf


func _hand_pick_interaction_lift_px() -> float:
	if not _hand_hover_visual_active or not is_instance_valid(card_visuals):
		return 0.0
	return maxf(0.0, -card_visuals.position.y * HAND_HOVER_PICK_LIFT_FOLLOW)


## 手牌交互命中：槽位基准 + 抬起时略微上移，便于点到上移后的卡面。
func _card_visuals_global_transform_for_hand_pick() -> Transform2D:
	var xf := _card_visuals_global_transform_at_rest()
	var lift := _hand_pick_interaction_lift_px()
	if lift > 0.001:
		xf.origin -= xf.y * lift
	return xf


func _get_hand_pick_global_quad() -> PackedVector2Array:
	return _local_rect_to_global_quad(
		_get_hand_pick_local_rect(),
		card_visuals.get_global_transform()
	)


func _get_hand_pick_global_quad_at_rest() -> PackedVector2Array:
	return _local_rect_to_global_quad(
		_get_hand_pick_local_rect(),
		_card_visuals_global_transform_for_hand_pick()
	)


func _get_hand_face_global_quad_at_rest() -> PackedVector2Array:
	return _local_rect_to_global_quad(
		_get_hand_face_local_rect(),
		_card_visuals_global_transform_at_rest()
	)


func _aabb_from_points(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var min_x := points[0].x
	var max_x := points[0].x
	var min_y := points[0].y
	var max_y := points[0].y
	for i in range(1, points.size()):
		min_x = minf(min_x, points[i].x)
		max_x = maxf(max_x, points[i].x)
		min_y = minf(min_y, points[i].y)
		max_y = maxf(max_y, points[i].y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


func _get_hand_pick_local_size() -> Vector2:
	return _get_hand_pick_local_rect().size


## 扇形旋转后 AABB 会比真实卡面大；命中须用旋转四边形，右侧牌否则明显错位。
func is_global_point_in_hand_pick(global_point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(global_point, _get_hand_pick_global_quad())


## 手牌扇形内的主目标/抬起判定：槽位基准；抬起时命中区随视觉上移一小段。
func is_global_point_in_hand_pick_at_rest(global_point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(global_point, _get_hand_pick_global_quad_at_rest())


## 抬起后随视觉上移的「突出段」：鼠标在此区域内则缩回，避免挡视野。
func is_global_point_in_hand_protrusion(global_point: Vector2) -> bool:
	if not _hand_hover_visual_active:
		return false
	if not is_global_point_in_hand_pick(global_point):
		return false
	return not is_global_point_in_hand_pick_at_rest(global_point)


func get_hand_pick_global_center() -> Vector2:
	if not is_instance_valid(card_visuals) or not card_visuals.is_inside_tree():
		return get_global_rect().get_center()
	var face := _get_hand_face_local_rect()
	return _card_visuals_global_transform_at_rest() * face.get_center()


func get_hand_pick_global_top_y() -> float:
	var quad := _get_hand_face_global_quad_at_rest()
	var top_y := quad[0].y
	for i in range(1, quad.size()):
		top_y = minf(top_y, quad[i].y)
	return top_y


func get_hand_base_pick_global_rect() -> Rect2:
	return _aabb_from_points(_get_hand_pick_global_quad())


func get_hand_active_pick_global_rect() -> Rect2:
	if _hand_hover_visual_active:
		return _aabb_from_points(_get_hand_pick_global_quad_at_rest())
	return get_hand_base_pick_global_rect()


func _compute_unified_hand_hover_visual_y() -> float:
	if not is_instance_valid(hand_slot) or not is_instance_valid(card_visuals):
		return -HAND_HOVER_LIFT_PX
	var hp := hand_slot.get_parent()
	if not (hp is Hand):
		return -HAND_HOVER_LIFT_PX
	var cur_top := get_hand_pick_global_top_y()
	var target_top := (hp as Hand).get_hand_hover_unified_global_top()
	return target_top - cur_top


func sync_hand_interaction_collision_from_layout(base_size: Vector2 = Vector2.ZERO) -> void:
	if not is_instance_valid(card_visuals):
		return
	var pick_rect := _get_hand_pick_local_rect()
	var hit := base_size
	if hit.x <= 0.001 or hit.y <= 0.001:
		hit = pick_rect.size
	var center := pick_rect.position + hit * 0.5
	if is_instance_valid(drop_point_detector):
		_apply_rect_pick_shape(drop_point_detector, hit, center)
	if is_instance_valid(card_visuals.area_2d):
		_apply_rect_pick_shape(card_visuals.area_2d, hit, center)


func _apply_rect_pick_shape(area: Area2D, size: Vector2, center: Vector2) -> void:
	if area == null:
		return
	var shape_node := area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	var rect_shape: RectangleShape2D
	if shape_node.shape is RectangleShape2D:
		rect_shape = shape_node.shape as RectangleShape2D
	else:
		rect_shape = RectangleShape2D.new()
		shape_node.shape = rect_shape
	rect_shape.size = size
	shape_node.position = center


func _sync_hand_area_input_pickable(foremost: bool) -> void:
	if has_meta(HAND_PICK_DELEGATE_META):
		mouse_filter = Control.MOUSE_FILTER_STOP
		if is_instance_valid(card_visuals):
			card_visuals.mouse_filter = Control.MOUSE_FILTER_STOP
		if is_instance_valid(card_visuals.area_2d):
			card_visuals.area_2d.input_pickable = true
		if is_instance_valid(drop_point_detector):
			drop_point_detector.input_pickable = true
		return
	if is_in_hand_combat_layout():
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if is_instance_valid(card_visuals):
			card_visuals.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if is_instance_valid(card_visuals.area_2d):
			card_visuals.area_2d.input_pickable = false
		if is_instance_valid(drop_point_detector):
			drop_point_detector.input_pickable = false
		return
	var pickable := foremost and not disabled
	mouse_filter = Control.MOUSE_FILTER_STOP if pickable else Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(card_visuals.area_2d):
		card_visuals.area_2d.input_pickable = pickable
	if is_instance_valid(drop_point_detector):
		drop_point_detector.input_pickable = pickable
	if is_instance_valid(card_visuals):
		card_visuals.mouse_filter = Control.MOUSE_FILTER_STOP if pickable else Control.MOUSE_FILTER_IGNORE


func _set_hand_hover_visual_active(active: bool) -> void:
	if active == _hand_hover_visual_active:
		return
	if not is_instance_valid(card_visuals):
		return
	_hand_hover_visual_active = active
	if active:
		card_visuals.panel.set("theme_override_styles/panel", card_visuals.main_panel_style_hover)
		refresh_combat_description()
		if is_instance_valid(hand_slot):
			hand_slot.rotation = 0.0
		_hand_hover_target_visual_y = _compute_unified_hand_hover_visual_y()
	else:
		card_visuals.panel.set("theme_override_styles/panel", card_visuals.main_panel_style_base)
		_restore_hand_slot_fan_rotation()
		_hand_hover_target_visual_y = 0.0
	var target_y := _hand_hover_target_visual_y if active else 0.0
	if not is_in_hand_combat_layout():
		_sync_hand_area_input_pickable(active and _is_hand_interaction_foremost())
	sync_hand_interaction_collision_from_layout()
	_tween_hand_hover_offset(target_y, 0.1)


## 重叠时仅「主目标」牌接收点击，其余牌设为 IGNORE 让事件穿透到下层牌。
## 注意：card_visuals 为 IGNORE 时子控件不会接收事件，所以我们单独设置各子控件，
## 保持 description_label 始终为 STOP 以便接收词条链接悬停事件。
func _apply_hand_visual_mouse_pick_filter() -> void:
	if not is_instance_valid(card_visuals) or not is_instance_valid(hand_slot):
		return
	var hp := hand_slot.get_parent()
	if not (hp is Hand):
		_sync_hand_area_input_pickable(true)
		return
	var is_foremost := _is_hand_interaction_foremost()
	_sync_hand_area_input_pickable(is_foremost)


## 递归设置 card_visuals 及其子控件的 mouse_filter
## 主目标牌：CardVisuals 用 STOP 接 gui_input；非主目标：IGNORE 让点击穿透到下层主目标。
## 抬起扩展区仍由 Area2D 补发点击。
func _set_card_visuals_mouse_filter_recursive(enabled: bool, _keep_description_active: bool = false) -> void:
	if not is_instance_valid(card_visuals):
		return
	
	card_visuals.mouse_filter = (
		Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	)
	
	# 所有子控件设为 IGNORE，让事件穿透到 Area2D
	if is_instance_valid(card_visuals.description_label):
		card_visuals.description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(card_visuals.get_node_or_null("%MainPanel")):
		card_visuals.get_node_or_null("%MainPanel").mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(card_visuals.get_node_or_null("%FramePanel")):
		card_visuals.get_node_or_null("%FramePanel").mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(card_visuals.get_node_or_null("%CostPanel")):
		card_visuals.get_node_or_null("%CostPanel").mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(card_visuals.get_node_or_null("%TitlePanel")):
		card_visuals.get_node_or_null("%TitlePanel").mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(card_visuals.get_node_or_null("%TypePanel")):
		card_visuals.get_node_or_null("%TypePanel").mouse_filter = Control.MOUSE_FILTER_IGNORE


## 回手等时机补一帧同步（Hand 也会在 `_process` 里持续刷新）。
func sync_hand_hover_lift_from_mouse() -> void:
	sync_hand_hover_presentation()


func play() -> void:
	if not card:
		return
	await _play_resolved()


func _play_resolved() -> void:
	var played_card := card
	var played_targets := targets.duplicate()
	var stats := char_stats
	var mods := player_modifiers
	# 仍在手牌槽内时先挂到 ui_layer，并立刻移除空槽：手牌保持拖出时的收窄，不再先空一块再缩
	var ui_layer := get_tree().get_first_node_in_group("ui_layer")
	var played_from_hand_slot: Control = null
	if ui_layer and is_instance_valid(hand_slot) and get_parent() == hand_slot:
		played_from_hand_slot = hand_slot
		var hp := played_from_hand_slot.get_parent()
		if hp and hp.has_method("shrink_slot_before_card_reparent_for_play"):
			hp.shrink_slot_before_card_reparent_for_play(played_from_hand_slot)
		reparent(ui_layer)
		apply_picked_card_layer_order()
		if hp and hp.has_method("remove_empty_slot_after_play"):
			hp.remove_empty_slot_after_play(played_from_hand_slot)
		hand_slot = null
	var start_center := get_global_rect().get_center()
	played_card.set_play_visual_start_center(start_center)

	if played_card.opens_hand_card_pick_on_play():
		played_card.prepare_hand_card_pick_before_effects()
	visible = false
	await played_card.play(played_targets, stats, mods, get_effective_mana_cost())

	var relic_h: RelicHandler = null
	var do_defect_echo := false
	var rn := get_tree().get_first_node_in_group("run")
	if rn:
		relic_h = rn.get("relic_handler") as RelicHandler
	if (
		relic_h
		and relic_h.has_relic("defect_machine")
		and DefectMachineRelic.has_echo_pending()
	):
		do_defect_echo = true
	if do_defect_echo:
		DefectMachineRelic.consume_echo()

	# 不用 class_name BattleCardFx，避免与 battle_card_fx.gd 的解析顺序/循环依赖导致 CardUI 无法加载
	var fx: Node = get_tree().get_first_node_in_group("battle_card_fx")
	if (
		fx
		and fx.is_inside_tree()
		and fx.has_method("animate_played_card")
		and not Events.is_combat_ended()
		and not played_card.defers_played_card_animation_to_effects()
	):
		# 与 res://scenes/ui/battle_card_fx.gd 中 PlayedKind 顺序一致：DISCARD=0, EXHAUST=1, POWER=2
		var kind: int = 0
		if played_card.exhausts:
			kind = 1
		elif played_card.type == Card.Type.POWER:
			kind = 2
		await fx.animate_played_card(played_card, start_center, kind)

	if (
		do_defect_echo
		and is_instance_valid(relic_h)
		and relic_h.has_relic("defect_machine")
		and fx
		and fx.is_inside_tree()
		and fx.has_method("animate_defect_machine_echo")
	):
		await fx.animate_defect_machine_echo(played_card, played_targets, stats, mods)

	await _flush_deferred_draw_pile_inserts_after_play()
	queue_free()


func _flush_deferred_draw_pile_inserts_after_play() -> void:
	var ph := get_tree().get_first_node_in_group("player_handler") as PlayerHandler
	if ph != null:
		await ph.flush_deferred_draw_pile_insert_animations()


func _resolve_enemy_from_target_node(node: Node) -> Enemy:
	if not is_instance_valid(node):
		return null
	if node is Enemy:
		return node as Enemy
	var current: Node = node.get_parent()
	while current != null:
		if current is Enemy and is_instance_valid(current):
			return current as Enemy
		current = current.get_parent()
	return null


func get_active_target_enemy() -> Enemy:
	_prune_invalid_targets()
	if targets.is_empty() or targets.size() > 1:
		return null
	return _resolve_enemy_from_target_node(targets[0])


func get_active_enemy_modifiers() -> ModifierHandler:
	var enemy := get_active_target_enemy()
	if enemy == null:
		return null
	var handler: ModifierHandler = enemy.modifier_handler
	if not is_instance_valid(handler):
		return null
	return handler


func _prune_invalid_targets() -> void:
	for i in range(targets.size() - 1, -1, -1):
		if not is_instance_valid(targets[i]):
			targets.remove_at(i)


func is_hovered() -> bool:
	return is_global_point_in_hand_pick(get_global_mouse_position())


func get_hand_hover_hit_global_rect() -> Rect2:
	return get_hand_active_pick_global_rect()


func is_hand_hover_hit_overlapping() -> bool:
	if disabled:
		return false
	return is_global_point_in_hand_pick(get_global_mouse_position())


func is_hand_pointer_over_this_card() -> bool:
	if disabled or not is_instance_valid(hand_slot) or get_parent() != hand_slot:
		return false
	var hp := hand_slot.get_parent()
	if not (hp is Hand):
		return false
	if (hp as Hand).get_mouse_foremost_hand_card() != self:
		return false
	return is_global_point_in_hand_pick_at_rest(get_global_mouse_position())


func refresh_combat_description() -> void:
	if not card or not is_instance_valid(card_visuals):
		return
	_prune_invalid_targets()
	var pm: ModifierHandler = player_modifiers if is_instance_valid(player_modifiers) else null
	var em: ModifierHandler = get_active_enemy_modifiers()
	var cp: Player = combat_player if is_instance_valid(combat_player) else null
	var te: Enemy = get_active_target_enemy()
	card_visuals.apply_modifier_context(pm, em, cp, te)
	refresh_mana_cost_display()


func get_effective_mana_cost() -> int:
	if not card or not char_stats:
		return card.cost if card else 0
	return PlayCostResolver.compute_mana_to_spend(card, char_stats, combat_player, player_modifiers)


func refresh_mana_cost_display() -> void:
	if not card or not is_instance_valid(card_visuals):
		return
	var want := get_effective_mana_cost()
	if char_stats:
		var affordable := char_stats.can_play_card(card, want, combat_player)
		if _blocked_only_by_play_requirements():
			affordable = PlayCostResolver.can_afford_mana(card, char_stats, want)
		card_visuals.set_combat_effective_mana_affordable(affordable)
	else:
		card_visuals.set_combat_effective_mana_affordable(true)
	if card.is_x_cost():
		card_visuals.set_display_mana_cost_override(-1)
	else:
		card_visuals.set_display_mana_cost_override(want if want != card.cost else -1)


func _on_gui_input(event: InputEvent) -> void:
	if Events.is_pointer_ui_obscured_for(self):
		return
	if has_meta(HAND_PICK_DELEGATE_META):
		var d: Variant = get_meta(HAND_PICK_DELEGATE_META)
		if d is Callable and (d as Callable).call(event):
			return
		## 自选模式：不交给 BaseState（playable=false 时拖拽判定会整段短路）
		return
	card_state_machine.on_gui_input(event)


func _on_mouse_entered() -> void:
	card_state_machine.on_mouse_entered()


func _on_mouse_exited() -> void:
	card_state_machine.on_mouse_exited()


func _set_card(value: Card) -> void:
	if not is_node_ready():
		await ready

	card = value
	card_visuals.card = card


func _set_playable(value: bool) -> void:
	playable = value
	if card and card.is_unplayable():
		card_visuals.icon.modulate = Color(1, 1, 1, 1)
		refresh_mana_cost_display()
		return
	if _blocked_only_by_play_requirements():
		card_visuals.icon.modulate = Color(1, 1, 1, 1)
		refresh_mana_cost_display()
		return
	## 手牌自选：仅禁止打出，卡图仍保持不透明
	if has_meta(HAND_PICK_DELEGATE_META):
		card_visuals.icon.modulate = Color(1, 1, 1, 1)
		refresh_mana_cost_display()
		return
	if not playable:
		card_visuals.icon.modulate = Color(1, 1, 1, 0.5)
	else:
		card_visuals.icon.modulate = Color(1, 1, 1, 1)
	refresh_mana_cost_display()


## 扩展 CardUI 的 Control 命中矩形，使其覆盖 CardVisuals 内 CollisionShape 区域（避免 gui_input 落在槽外「空白」）。
## 仅在手牌自选层生效期间调用；回手后由 Hand 统一写 offset，不可在无 meta 时改尺寸，否则会把手牌撑高。
## 与碰撞盒合并时保留完整纵向范围（自选结束会由 Hand 再次写回槽尺寸）。
func sync_gui_rect_to_pick_collision() -> void:
	if not has_meta(HAND_PICK_DELEGATE_META):
		return
	if not is_instance_valid(hand_slot) or get_parent() != hand_slot:
		return
	if not is_instance_valid(card_visuals):
		return
	if not is_equal_approx(card_visuals.position.y, 0.0):
		reset_hand_hover_lift_instant()
	var gr := card_visuals.get_pick_collision_global_rect()
	if gr.size.x <= 0.001 or gr.size.y <= 0.001:
		return
	var inv := get_global_transform().affine_inverse()
	var corners: Array[Vector2] = [
		gr.position,
		Vector2(gr.end.x, gr.position.y),
		gr.end,
		Vector2(gr.position.x, gr.end.y)
	]
	var mn := inv * corners[0]
	var mx := mn
	for i in range(1, 4):
		var lp := inv * corners[i]
		mn = mn.min(lp)
		mx = mx.max(lp)
	var pick_local := Rect2(mn, mx - mn)
	var base := Rect2(offset_left, offset_top, offset_right - offset_left, offset_bottom - offset_top)
	var merged := base.merge(pick_local)
	offset_left = merged.position.x
	offset_top = merged.position.y
	offset_right = merged.end.x
	offset_bottom = merged.end.y
	custom_minimum_size = merged.size


func _set_char_stats(value: CharacterStats) -> void:
	char_stats = value
	char_stats.stats_changed.connect(_on_char_stats_changed)
	_on_char_stats_changed()


func _on_drop_point_detector_area_entered(area: Area2D) -> void:
	if not is_instance_valid(area):
		return
	# DropPointDetector 的 mask 对准 card_drop_area（如战斗 CardDropArea），不是敌人层。
	if not targets.has(area):
		targets.append(area)
	refresh_combat_description()


func _on_drop_point_detector_area_exited(area: Area2D) -> void:
	_prune_invalid_targets()
	if is_instance_valid(area):
		targets.erase(area)
	else:
		_prune_invalid_targets()
	refresh_combat_description()


func _on_other_card_drag_started(used_card: CardUI) -> void:
	if used_card == self:
		return
	disabled = true
	z_index = 0


func _on_other_card_aim_started(used_card: CardUI) -> void:
	if used_card == self:
		return
	disabled = true
	z_index = 0


func _on_card_drag_or_aim_ended(_card: CardUI) -> void:
	disabled = false
	playable = char_stats.can_play_card(card, get_effective_mana_cost(), combat_player)


func _on_char_stats_changed() -> void:
	if card:
		playable = char_stats.can_play_card(card, get_effective_mana_cost(), combat_player)
		refresh_combat_description()
