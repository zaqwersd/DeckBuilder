class_name CardVisuals
extends Control

const STYLE_BASE := preload("res://scenes/card_ui/card_base_stylebox.tres")
const STYLE_HOVER := preload("res://scenes/card_ui/card_hover_stylebox.tres")
const STYLE_DRAG := preload("res://scenes/card_ui/card_drag_stylebox.tres")

const TYPE_DISPLAY := {
	Card.Type.ATTACK: "攻击",
	Card.Type.SKILL: "技能",
	Card.Type.POWER: "能力",
	Card.Type.STATUS: "状态",
}

## Blade 角色卡主底板填充色 #009688（RGB 0,150,136）
const BLADE_MAIN_BG := Color(0.0 / 255.0, 150.0 / 255.0, 136.0 / 255.0, 1.0)

## 非 Blade：不透明内层底板（原先用 STYLE 底色 + 透明度）
const INNER_COST_BG := Color(0.12, 0.12, 0.12, 1.0)
const INNER_TITLE_BG := Color(0.16, 0.16, 0.16, 1.0)
const INNER_TYPE_BG := Color(0.16, 0.16, 0.16, 1.0)

## Blade：同色相略亮，与主底区分且便于读字
const BLADE_INNER_COST_BG := Color(18.0 / 255.0, 168.0 / 255.0, 154.0 / 255.0, 1.0)
const BLADE_INNER_TITLE_BG := Color(26.0 / 255.0, 176.0 / 255.0, 162.0 / 255.0, 1.0)
const BLADE_INNER_TYPE_BG := Color(26.0 / 255.0, 176.0 / 255.0, 162.0 / 255.0, 1.0)

## 状态牌（如 common_cards）：#616161，各 Panel 填充统一
const STATUS_PANEL_BG := Color(97.0 / 255.0, 97.0 / 255.0, 97.0 / 255.0, 1.0)

@export var card: Card : set = set_card

## 主底板（与 CardState 的 hover / drag 切换共用）
@onready var panel: Panel = %MainPanel
@onready var frame_panel: Panel = %FramePanel
@onready var cost_panel: Panel = %CostPanel
@onready var title_panel: Panel = %TitlePanel
@onready var type_panel: Panel = %TypePanel
@onready var cost: Label = %CostLabel
@onready var icon: TextureRect = %CardImage
@onready var name_label: Label = %CardName
@onready var type_label: Label = %CardTypeLabel
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


func _is_blade_card() -> bool:
	return card != null and card.id.begins_with("blade_")


func _is_status_card() -> bool:
	return card != null and card.type == Card.Type.STATUS


func _rebuild_main_panel_styles() -> void:
	main_panel_style_base = _with_rarity_border(STYLE_BASE.duplicate() as StyleBoxFlat, card.rarity)
	main_panel_style_hover = _with_rarity_border(STYLE_HOVER.duplicate() as StyleBoxFlat, card.rarity)
	main_panel_style_drag = _with_rarity_border(STYLE_DRAG.duplicate() as StyleBoxFlat, card.rarity)
	if _is_status_card():
		main_panel_style_base.bg_color = STATUS_PANEL_BG
		main_panel_style_hover.bg_color = STATUS_PANEL_BG
		main_panel_style_drag.bg_color = STATUS_PANEL_BG
	elif _is_blade_card():
		main_panel_style_base.bg_color = BLADE_MAIN_BG
		main_panel_style_hover.bg_color = BLADE_MAIN_BG
		main_panel_style_drag.bg_color = BLADE_MAIN_BG


func _with_rarity_border(sb: StyleBoxFlat, rarity: Card.Rarity) -> StyleBoxFlat:
	sb.border_color = Card.RARITY_COLORS[rarity]
	return sb


func _apply_rarity_panel_borders() -> void:
	var r := card.rarity
	panel.add_theme_stylebox_override("panel", main_panel_style_base)
	var frame_fill := STATUS_PANEL_BG if _is_status_card() else Color(0, 0, 0, 0)
	frame_panel.add_theme_stylebox_override("panel", _inner_panel_style_opaque(r, frame_fill))
	var show_cost := card.cost >= 0
	cost_panel.visible = show_cost
	if show_cost:
		cost_panel.add_theme_stylebox_override("panel", _inner_panel_style_opaque(r, _inner_cost_fill()))
	else:
		cost_panel.remove_theme_stylebox_override("panel")
	title_panel.add_theme_stylebox_override("panel", _inner_panel_style_opaque(r, _inner_title_fill()))
	type_panel.add_theme_stylebox_override("panel", _inner_panel_style_opaque(r, _inner_type_fill()))


func _inner_cost_fill() -> Color:
	if _is_status_card():
		return STATUS_PANEL_BG
	return BLADE_INNER_COST_BG if _is_blade_card() else INNER_COST_BG


func _inner_title_fill() -> Color:
	if _is_status_card():
		return STATUS_PANEL_BG
	return BLADE_INNER_TITLE_BG if _is_blade_card() else INNER_TITLE_BG


func _inner_type_fill() -> Color:
	if _is_status_card():
		return STATUS_PANEL_BG
	return BLADE_INNER_TYPE_BG if _is_blade_card() else INNER_TYPE_BG


func _inner_panel_style_opaque(rarity: Card.Rarity, fill: Color) -> StyleBoxFlat:
	var sb := STYLE_BASE.duplicate() as StyleBoxFlat
	sb.bg_color = fill
	sb.border_color = Card.RARITY_COLORS[rarity]
	return sb


func _sync_from_card() -> void:
	if card.cost >= 0:
		cost.text = str(card.cost)
	else:
		cost.text = ""
	icon.texture = card.icon
	name_label.text = card.get_display_name()
	type_label.text = TYPE_DISPLAY.get(card.type, "")
	_refresh_description_text()


func _refresh_description_text() -> void:
	if card == null:
		return
	if _player_modifiers != null or _enemy_modifiers != null:
		description_label.text = card.get_updated_visual_description_bbcode(_player_modifiers, _enemy_modifiers)
	else:
		description_label.text = card.get_visual_description_bbcode()
