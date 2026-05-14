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

@onready var card_visuals: CardVisuals = $CardVisuals
@onready var drop_point_detector: Area2D = $DropPointDetector
@onready var card_state_machine: CardStateMachine = $CardStateMachine
@onready var targets: Array[Node] = []

var combat_player: Player
var original_index := 0
var parent: Control
var tween: Tween
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
	if is_instance_valid(card_visuals):
		## CardVisuals 为全锚点铺满父节点时，用 offset 二态（0 / -抬起量），不用 tween，避免中间高度。
		card_visuals.offset_top = 0.0
		card_visuals.offset_bottom = 0.0
		card_visuals.position = Vector2.ZERO


## 禁用手牌等：收起抬起并恢复底板样式（不依赖状态机）。
func force_hand_hover_visuals_off() -> void:
	z_index = 0
	z_as_relative = true
	if is_instance_valid(card_visuals):
		card_visuals.panel.set("theme_override_styles/panel", card_visuals.main_panel_style_base)
		card_visuals.mouse_filter = Control.MOUSE_FILTER_STOP
	reset_hand_hover_lift_instant()


## 手牌悬停：卡面仅在「正常(0)」与「抬起(-HAND_HOVER_LIFT_PX)」两档，不用动画避免半抬起。
func _apply_hand_hover_offset_immediate() -> void:
	if not is_instance_valid(card_visuals):
		return
	var y_off := -HAND_HOVER_LIFT_PX if _hand_hover_visual_active else 0.0
	card_visuals.offset_top = y_off
	card_visuals.offset_bottom = y_off


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
		_apply_hand_hover_offset_immediate()
		if is_instance_valid(card_visuals):
			card_visuals.mouse_filter = Control.MOUSE_FILTER_STOP
		return
	var sm := card_state_machine
	if not sm or not sm.current_state:
		return
	if sm.current_state.state != CardState.State.BASE:
		_set_hand_hover_visual_active(false)
		_apply_hand_hover_offset_immediate()
		if is_instance_valid(card_visuals):
			card_visuals.mouse_filter = Control.MOUSE_FILTER_STOP
		return
	_apply_hand_visual_mouse_pick_filter()
	_set_hand_hover_visual_active(is_hand_pointer_over_this_card())
	_apply_hand_hover_offset_immediate()


func _hand_hover_visual_offsets_not_snapped() -> bool:
	if not is_instance_valid(card_visuals):
		return false
	var t := card_visuals.offset_top
	var b := card_visuals.offset_bottom
	if not is_equal_approx(t, b):
		return true
	if absf(t) <= 0.01:
		return false
	return not is_equal_approx(t, -HAND_HOVER_LIFT_PX)


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
	_apply_hand_hover_offset_immediate()


## 重叠时仅「主目标」牌接收点击，其余牌 CardVisuals 设为 IGNORE 让事件穿透到下层牌。
func _apply_hand_visual_mouse_pick_filter() -> void:
	if not is_instance_valid(card_visuals) or not is_instance_valid(hand_slot):
		return
	var hp := hand_slot.get_parent()
	if not (hp is Hand):
		card_visuals.mouse_filter = Control.MOUSE_FILTER_STOP
		return
	var fo := (hp as Hand).get_mouse_foremost_hand_card()
	var overlapping := is_hand_hover_hit_overlapping()
	if overlapping and fo != null and fo != self:
		card_visuals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		card_visuals.mouse_filter = Control.MOUSE_FILTER_STOP


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
	played_card.play(played_targets, stats, mods, get_effective_mana_cost())

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
func get_hand_hover_hit_global_rect() -> Rect2:
	var gr := get_global_rect()
	return Rect2(
		gr.position + Vector2(0, -HAND_HOVER_LIFT_PX),
		gr.size + Vector2(0, HAND_HOVER_LIFT_PX)
	)


func is_hand_hover_hit_overlapping() -> bool:
	if disabled:
		return false
	return get_hand_hover_hit_global_rect().has_point(get_global_mouse_position())


## 手牌内：须为本条手里「主目标」牌；未抬起时只用卡面本体命中（避免鼠标在手牌上方空白处误判）；已抬起后用扩展区保持手感。
func is_hand_pointer_over_this_card() -> bool:
	if disabled or not is_instance_valid(hand_slot) or get_parent() != hand_slot:
		return false
	var hp := hand_slot.get_parent()
	if not (hp is Hand):
		return false
	if (hp as Hand).get_mouse_foremost_hand_card() != self:
		return false
	if _hand_hover_visual_active:
		return is_hand_hover_hit_overlapping()
	return get_global_rect().has_point(get_global_mouse_position())


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
