class_name CardVisuals
extends Control

const STYLE_BASE := preload("res://scenes/card_ui/card_base_stylebox.tres")
const STYLE_HOVER := preload("res://scenes/card_ui/card_hover_stylebox.tres")
const STYLE_DRAG := preload("res://scenes/card_ui/card_drag_stylebox.tres")

@export var card: Card : set = set_card

## 主底板（与 CardState 的 hover / drag 切换共用）
@onready var panel: Panel = %MainPanel
@onready var frame_panel: Panel = %FramePanel
@onready var cost_panel: Panel = %CostPanel
@onready var title_panel: Panel = %TitlePanel
@onready var cost: Label = %CostLabel
@onready var icon: TextureRect = %CardImage
@onready var name_label: Label = %CardName
@onready var description_label: RichTextLabel = %CardDescription

var _player_modifiers: ModifierHandler
var _enemy_modifiers: ModifierHandler

## 稀有度着色后的主面板样式（供 CardUI / CardMenuUI 使用）
var main_panel_style_base: StyleBoxFlat
var main_panel_style_hover: StyleBoxFlat
var main_panel_style_drag: StyleBoxFlat


func set_card(value: Card) -> void:
	if value == null:
		return
	if not is_node_ready():
		await ready

	card = value
	_rebuild_main_panel_styles()
	_apply_rarity_panel_borders()
	_sync_from_card()


func apply_modifier_context(player_modifiers: ModifierHandler, enemy_modifiers: ModifierHandler) -> void:
	_player_modifiers = player_modifiers
	_enemy_modifiers = enemy_modifiers
	_refresh_description_text()


func _rebuild_main_panel_styles() -> void:
	main_panel_style_base = _with_rarity_border(STYLE_BASE.duplicate() as StyleBoxFlat, card.rarity)
	main_panel_style_hover = _with_rarity_border(STYLE_HOVER.duplicate() as StyleBoxFlat, card.rarity)
	main_panel_style_drag = _with_rarity_border(STYLE_DRAG.duplicate() as StyleBoxFlat, card.rarity)


func _with_rarity_border(sb: StyleBoxFlat, rarity: Card.Rarity) -> StyleBoxFlat:
	sb.border_color = Card.RARITY_COLORS[rarity]
	return sb


func _apply_rarity_panel_borders() -> void:
	var r := card.rarity
	panel.add_theme_stylebox_override("panel", main_panel_style_base)
	frame_panel.add_theme_stylebox_override("panel", _inner_panel_style(r, 0.0))
	cost_panel.add_theme_stylebox_override("panel", _inner_panel_style(r, 0.35))
	title_panel.add_theme_stylebox_override("panel", _inner_panel_style(r, 0.55))


func _inner_panel_style(rarity: Card.Rarity, bg_alpha: float) -> StyleBoxFlat:
	var sb := STYLE_BASE.duplicate() as StyleBoxFlat
	if bg_alpha <= 0.001:
		sb.bg_color = Color(0, 0, 0, 0)
	else:
		var c := sb.bg_color
		c.a = bg_alpha
		sb.bg_color = c
	sb.border_color = Card.RARITY_COLORS[rarity]
	return sb


func _sync_from_card() -> void:
	cost.text = str(card.cost)
	icon.texture = card.icon
	name_label.text = card.get_display_name()
	_refresh_description_text()


func _refresh_description_text() -> void:
	if card == null:
		return
	if _player_modifiers != null or _enemy_modifiers != null:
		description_label.text = card.get_updated_visual_description_bbcode(_player_modifiers, _enemy_modifiers)
	else:
		description_label.text = card.get_visual_description_bbcode()
