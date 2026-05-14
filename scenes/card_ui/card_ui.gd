class_name CardUI
extends Control

## 手牌内鼠标悬停时卡牌上移的像素
const HAND_HOVER_LIFT_PX := 80.0
const HAND_HOVER_Z := 10

signal reparent_requested(which_card_ui: CardUI)

const BASE_STYLEBOX := preload("res://scenes/card_ui/card_base_stylebox.tres")
const DRAG_STYLEBOX := preload("res://scenes/card_ui/card_drag_stylebox.tres")
const HOVER_STYLEBOX := preload("res://scenes/card_ui/card_hover_stylebox.tres")

@export var player_modifiers: ModifierHandler
@export var card: Card : set = _set_card
@export var char_stats: CharacterStats : set = _set_char_stats

@onready var card_visuals: CardVisualsBase = $CardVisuals
@onready var drop_point_detector: Area2D = $DropPointDetector
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


func _ready() -> void:
	Events.card_aim_started.connect(_on_card_drag_or_aiming_started)
	Events.card_drag_started.connect(_on_card_drag_or_aiming_started)
	Events.card_drag_ended.connect(_on_card_drag_or_aim_ended)
	Events.card_aim_ended.connect(_on_card_drag_or_aim_ended)
	card_state_machine.init(self)
	if is_instance_valid(card_visuals):
		# IGNORE 时上移后的卡图会超出 CardUI 的命中框，点击「抬起区域」收不到 gui_input，导致有抬起却无法出牌
		card_visuals.mouse_filter = Control.MOUSE_FILTER_STOP
		if not card_visuals.gui_input.is_connected(_on_card_visuals_gui_input):
			card_visuals.gui_input.connect(_on_card_visuals_gui_input)
		card_visuals.number_bbcode_style = Card.NumberBbcodeStyle.COMBAT_PILES_AND_HAND


func _on_card_visuals_gui_input(event: InputEvent) -> void:
	if Events.is_pointer_ui_obscured_for(self):
		return
	_on_gui_input(event)


func _input(event: InputEvent) -> void:
	if Events.is_pointer_ui_obscured_for(self):
		return
	card_state_machine.on_input(event)


func animate_to_position(new_position: Vector2, duration: float) -> void:
	tween = create_tween().set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", new_position, duration)


func allows_hand_drag_preview() -> bool:
	if not card or not char_stats:
		return false
	if card.cost < 0:
		return true
	return card.type == Card.Type.STATUS and not char_stats.can_play_card(card)


func reset_hand_hover_lift_instant() -> void:
	_hand_hover_visual_active = false
	if _hover_lift_tween and _hover_lift_tween.is_running():
		_hover_lift_tween.kill()
		_hover_lift_tween = null
	## 强制 CardVisuals 回到基准位置（y = 0）
	if is_instance_valid(card_visuals):
		card_visuals.position.y = 0.0


## 禁用手牌等：收起抬起并恢复底板样式（不依赖状态机）。
func force_hand_hover_visuals_off() -> void:
	z_index = 0
	z_as_relative = true
	if is_instance_valid(card_visuals):
		card_visuals.panel.set("theme_override_styles/panel", card_visuals.main_panel_style_base)
		card_visuals.mouse_filter = Control.MOUSE_FILTER_STOP
	reset_hand_hover_lift_instant()


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
	
	## 安全处理：如果当前值异常（不在 0 或 -HAND_HOVER_LIFT_PX 附近），强制重置为 0
	var is_current_valid := (
		is_equal_approx(current_y, 0.0) 
		or is_equal_approx(current_y, -HAND_HOVER_LIFT_PX)
	)
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
	_hover_lift_tween.tween_property(card_visuals, "position:y", target_y, duration)
	## 动画完成回调：确保最终值精确到位
	_hover_lift_tween.finished.connect(
		func() -> void:
			if is_instance_valid(card_visuals):
				card_visuals.position.y = target_y
	, CONNECT_ONE_SHOT)


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
		_set_hand_hover_visual_active(false)
		if is_instance_valid(card_visuals):
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
	_apply_hand_visual_mouse_pick_filter()
	_set_hand_hover_visual_active(is_hand_pointer_over_this_card())


func _hand_hover_visual_offsets_not_snapped() -> bool:
	if not is_instance_valid(card_visuals):
		return false
	## 有正在运行的抬起动画时，视为未对齐到最终状态
	if _hover_lift_tween and _hover_lift_tween.is_running():
		return true
	var y := card_visuals.position.y
	## 检查是否在有效位置（0 或 -HAND_HOVER_LIFT_PX）
	if is_equal_approx(y, 0.0):
		return false
	if is_equal_approx(y, -HAND_HOVER_LIFT_PX):
		return false
	return true


func _set_hand_hover_visual_active(active: bool) -> void:
	if active == _hand_hover_visual_active:
		return
	if not is_instance_valid(card_visuals):
		return
	_hand_hover_visual_active = active
	if active:
		z_index = HAND_HOVER_Z
		z_as_relative = true
		card_visuals.panel.set("theme_override_styles/panel", card_visuals.main_panel_style_hover)
		refresh_combat_description()
	else:
		z_index = 0
		z_as_relative = true
		card_visuals.panel.set("theme_override_styles/panel", card_visuals.main_panel_style_base)
	## 0.1s tween 动画切换到目标位置：突出(-HAND_HOVER_LIFT_PX) 或 正常(0)
	## 动画进行中时如果状态再次变化，必须等当前动画完成或强制结束后再开始新动画
	var target_y := -HAND_HOVER_LIFT_PX if active else 0.0
	_tween_hand_hover_offset(target_y, 0.1)


## 重叠时仅「主目标」牌接收点击，其余牌设为 IGNORE 让事件穿透到下层牌。
## 注意：card_visuals 为 IGNORE 时子控件不会接收事件，所以我们单独设置各子控件，
## 保持 description_label 始终为 STOP 以便接收词条链接悬停事件。
func _apply_hand_visual_mouse_pick_filter() -> void:
	if not is_instance_valid(card_visuals) or not is_instance_valid(hand_slot):
		return
	var hp := hand_slot.get_parent()
	if not (hp is Hand):
		# 不在手牌中：允许所有交互
		_set_card_visuals_mouse_filter_recursive(true)
		return
	var fo := (hp as Hand).get_mouse_foremost_hand_card()
	var overlapping := is_hand_hover_hit_overlapping()
	var is_foremost := (fo == self)
	if overlapping and fo != null and not is_foremost:
		# 非主目标：设为 IGNORE，但保持 description_label 可接收事件
		_set_card_visuals_mouse_filter_recursive(false, true)
	else:
		# 主目标：允许所有交互
		_set_card_visuals_mouse_filter_recursive(true, true)


## 递归设置 card_visuals 及其子控件的 mouse_filter
## @param enabled: true 表示主目标（STOP），false 表示非主目标（IGNORE）
## @param keep_description_active: true 时保持 description_label 为 STOP
func _set_card_visuals_mouse_filter_recursive(enabled: bool, keep_description_active: bool = false) -> void:
	if not is_instance_valid(card_visuals):
		return
	
	# 始终将 card_visuals 设为 STOP，以便子控件可以接收事件
	card_visuals.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 单独设置各个子控件
	if is_instance_valid(card_visuals.description_label):
		# 描述区需要始终接收事件以便词条链接悬停
		card_visuals.description_label.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 其他子控件根据是否主目标设置
	var child_filter := Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	
	if is_instance_valid(card_visuals.get_node_or_null("%MainPanel")):
		card_visuals.get_node_or_null("%MainPanel").mouse_filter = child_filter
	if is_instance_valid(card_visuals.get_node_or_null("%FramePanel")):
		card_visuals.get_node_or_null("%FramePanel").mouse_filter = child_filter
	if is_instance_valid(card_visuals.get_node_or_null("%CostPanel")):
		card_visuals.get_node_or_null("%CostPanel").mouse_filter = child_filter
	if is_instance_valid(card_visuals.get_node_or_null("%TitlePanel")):
		card_visuals.get_node_or_null("%TitlePanel").mouse_filter = child_filter
	if is_instance_valid(card_visuals.get_node_or_null("%TypePanel")):
		card_visuals.get_node_or_null("%TypePanel").mouse_filter = child_filter


## 回手等时机补一帧同步（Hand 也会在 `_process` 里持续刷新）。
func sync_hand_hover_lift_from_mouse() -> void:
	sync_hand_hover_presentation()


func play() -> void:
	if not card:
		return
	_play_resolved()


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
		move_to_front()
		z_index = 128
		z_as_relative = false
		if hp and hp.has_method("remove_empty_slot_after_play"):
			hp.remove_empty_slot_after_play(played_from_hand_slot)
		hand_slot = null
	var start_center := get_global_rect().get_center()

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
	if fx and fx.is_inside_tree() and fx.has_method("animate_played_card") and not Events.is_combat_ended():
		# 与 res://scenes/ui/battle_card_fx.gd 中 PlayedKind 顺序一致：DISCARD=0, EXHAUST=1, POWER=2
		var kind: int = 0
		if played_card.exhausts:
			kind = 1
		elif played_card.type == Card.Type.POWER:
			kind = 2
		await fx.animate_played_card(played_card, start_center, kind)

	if (
		do_defect_echo
		and not Events.is_combat_ended()
		and is_instance_valid(relic_h)
		and relic_h.has_relic("defect_machine")
		and fx
		and fx.is_inside_tree()
		and fx.has_method("animate_defect_machine_echo")
	):
		await fx.animate_defect_machine_echo(played_card, played_targets, stats, mods)

	queue_free()


func get_active_enemy_modifiers() -> ModifierHandler:
	_prune_invalid_targets()
	if targets.is_empty() or targets.size() > 1:
		return null
	var t: Node = targets[0]
	if not is_instance_valid(t):
		return null
	if not (t is Enemy):
		return null
	return (t as Enemy).modifier_handler


func _prune_invalid_targets() -> void:
	for i in range(targets.size() - 1, -1, -1):
		if not is_instance_valid(targets[i]):
			targets.remove_at(i)


func is_hovered() -> bool:
	var rect := Rect2(Vector2.ZERO, self.size)
	return rect.has_point(get_local_mouse_position())


## 手牌悬停抬起后视觉在控件矩形上方，与 tooltip 一致：用「扩展矩形」判断是否仍算指着这张牌。
## 使用 CardVisuals 的全局矩形作为命中区（精确匹配卡牌视觉区域，不过度扩展）
func get_hand_hover_hit_global_rect() -> Rect2:
	if not is_instance_valid(card_visuals):
		return get_global_rect()
	
	## 直接使用 card_visuals 的全局矩形作为命中区
	## 不再向上过度扩展，只添加少量缓冲（20像素）用于边缘容错
	var visuals_rect := card_visuals.get_global_rect()
	var buffer := 20.0
	return Rect2(
		visuals_rect.position - Vector2(buffer * 0.5, buffer * 0.5),
		visuals_rect.size + Vector2(buffer, buffer)
	)


func is_hand_hover_hit_overlapping() -> bool:
	if disabled:
		return false
	return get_hand_hover_hit_global_rect().has_point(get_global_mouse_position())


## 手牌内：须为本条手里「主目标」牌；使用固定命中区域（不考虑当前是否抬起）
func is_hand_pointer_over_this_card() -> bool:
	if disabled or not is_instance_valid(hand_slot) or get_parent() != hand_slot:
		return false
	var hp := hand_slot.get_parent()
	if not (hp is Hand):
		return false
	if (hp as Hand).get_mouse_foremost_hand_card() != self:
		return false
	## 使用扩展命中区（包含抬起区域），不依赖当前动画状态
	return is_hand_hover_hit_overlapping()


func refresh_combat_description() -> void:
	if not card or not is_instance_valid(card_visuals):
		return
	_prune_invalid_targets()
	card_visuals.apply_modifier_context(player_modifiers, get_active_enemy_modifiers(), combat_player)
	refresh_mana_cost_display()


func get_effective_mana_cost() -> int:
	if not card or card.cost < 0:
		return card.cost if card else 0
	var base := card.cost
	if combat_player and is_instance_valid(combat_player) and card.type == Card.Type.ATTACK:
		base += OverwhelmingStatus.stacks_on_player(combat_player)
	return base


func refresh_mana_cost_display() -> void:
	if not card or not is_instance_valid(card_visuals):
		return
	var want := get_effective_mana_cost()
	if char_stats:
		card_visuals.set_combat_effective_mana_affordable(char_stats.can_play_card(card, want))
	else:
		card_visuals.set_combat_effective_mana_affordable(true)
	card_visuals.set_display_mana_cost_override(want if want != card.cost else -1)


func _on_gui_input(event: InputEvent) -> void:
	if Events.is_pointer_ui_obscured_for(self):
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
	if card and card.cost < 0:
		card_visuals.icon.modulate = Color(1, 1, 1, 1)
		return
	if not playable:
		card_visuals.icon.modulate = Color(1, 1, 1, 0.5)
	else:
		card_visuals.icon.modulate = Color(1, 1, 1, 1)
	refresh_mana_cost_display()


func _set_char_stats(value: CharacterStats) -> void:
	char_stats = value
	char_stats.stats_changed.connect(_on_char_stats_changed)
	_on_char_stats_changed()


func _on_drop_point_detector_area_entered(area: Area2D) -> void:
	if not targets.has(area):
		targets.append(area)
		refresh_combat_description()


func _on_drop_point_detector_area_exited(area: Area2D) -> void:
	targets.erase(area)
	refresh_combat_description()


func _on_card_drag_or_aiming_started(used_card: CardUI) -> void:
	if used_card == self:
		return
	
	disabled = true
	z_index = 0


func _on_card_drag_or_aim_ended(_card: CardUI) -> void:
	disabled = false
	playable = char_stats.can_play_card(card, get_effective_mana_cost())


func _on_char_stats_changed() -> void:
	if card:
		playable = char_stats.can_play_card(card, get_effective_mana_cost())
		refresh_combat_description()
