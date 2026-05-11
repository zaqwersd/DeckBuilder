class_name CardUI
extends Control

## 手牌内鼠标悬停时卡牌上移的像素（与 `card_base_state` 一致）
const HAND_HOVER_LIFT_PX := 80.0

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

var original_index := 0
var parent: Control
var tween: Tween
## 与 `animate_to_position` 分离，避免手牌悬停抬起动画被 BASE 状态里 kill 掉主 tween 时误伤
var hover_lift_tween: Tween
## 由 Hand.add_card 写入：卡牌所属手牌槽，用于悬停位移与回手排序（避免 HBox 每帧盖写 position）
var hand_slot: Control
var playable := true : set = _set_playable
var disabled := true


func _ready() -> void:
	Events.card_aim_started.connect(_on_card_drag_or_aiming_started)
	Events.card_drag_started.connect(_on_card_drag_or_aiming_started)
	Events.card_drag_ended.connect(_on_card_drag_or_aim_ended)
	Events.card_aim_ended.connect(_on_card_drag_or_aim_ended)
	card_state_machine.init(self)


func _input(event: InputEvent) -> void:
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
	if hover_lift_tween and hover_lift_tween.is_running():
		hover_lift_tween.kill()
	hover_lift_tween = null
	position.y = 0.0


func tween_hand_hover_lift_y(target_y: float, duration: float = 0.12) -> void:
	if hover_lift_tween and hover_lift_tween.is_running():
		hover_lift_tween.kill()
	hover_lift_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hover_lift_tween.tween_property(self, "position:y", target_y, duration)


func sync_hand_hover_lift_from_mouse() -> void:
	if disabled:
		return
	if is_hovered():
		tween_hand_hover_lift_y(-HAND_HOVER_LIFT_PX)
	else:
		reset_hand_hover_lift_instant()


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
	played_card.play(played_targets, stats, mods)

	# 不用 class_name BattleCardFx，避免与 battle_card_fx.gd 的解析顺序/循环依赖导致 CardUI 无法加载
	var fx: Node = get_tree().get_first_node_in_group("battle_card_fx")
	if fx and fx.is_inside_tree() and fx.has_method("animate_played_card"):
		# 与 res://scenes/ui/battle_card_fx.gd 中 PlayedKind 顺序一致：DISCARD=0, EXHAUST=1, POWER=2
		var kind: int = 0
		if played_card.exhausts:
			kind = 1
		elif played_card.type == Card.Type.POWER:
			kind = 2
		await fx.animate_played_card(played_card, start_center, kind, mods)

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


func refresh_combat_description() -> void:
	if not card or not is_instance_valid(card_visuals):
		return
	_prune_invalid_targets()
	card_visuals.apply_modifier_context(player_modifiers, get_active_enemy_modifiers())


func _on_gui_input(event: InputEvent) -> void:
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
		card_visuals.cost.add_theme_color_override("font_color", Color.RED)
		card_visuals.icon.modulate = Color(1, 1, 1, 0.5)
	else:
		card_visuals.cost.remove_theme_color_override("font_color")
		card_visuals.icon.modulate = Color(1, 1, 1, 1)


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
	playable = char_stats.can_play_card(card)


func _on_char_stats_changed() -> void:
	if card:
		playable = char_stats.can_play_card(card)
		refresh_combat_description()
