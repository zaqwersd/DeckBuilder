class_name CardVisualsBase
extends Control

## 卡牌视觉基类，提供共享的基础设施。
## 子类 CombatCardVisuals 和 ListingCardVisuals 分别实现战斗中和战斗外的显示规则。

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

## 非 Blade：不透明内层底板
const INNER_COST_BG := Color(0.12, 0.12, 0.12, 1.0)
const INNER_TITLE_BG := Color(0.16, 0.16, 0.16, 1.0)
const INNER_TYPE_BG := Color(0.16, 0.16, 0.16, 1.0)

## Blade：同色相略亮
const BLADE_INNER_COST_BG := Color(18.0 / 255.0, 168.0 / 255.0, 154.0 / 255.0, 1.0)
const BLADE_INNER_TITLE_BG := Color(26.0 / 255.0, 176.0 / 255.0, 162.0 / 255.0, 1.0)
const BLADE_INNER_TYPE_BG := Color(26.0 / 255.0, 176.0 / 255.0, 162.0 / 255.0, 1.0)

## 状态牌灰底
const STATUS_PANEL_BG := Color(97.0 / 255.0, 97.0 / 255.0, 97.0 / 255.0, 1.0)

## 卡面整体被 scale 缩小时，保证屏幕上文字至少该像素
const MIN_SCREEN_CARD_TEXT_PX := 16

## 至少升级过一次的卡：名称与升级角标字色 #72d572
const UPGRADED_CARD_ACCENT := Color(0x72 / 255.0, 0xd5 / 255.0, 0x72 / 255.0, 1.0)
const UPGRADED_FONT_OUTLINE := Color(0x05 / 255.0, 0x6f / 255.0, 0.0 / 255.0, 1.0)

## 卡面描述 RichTextLabel 字号
const CARD_DESC_FONT_NORMAL_PX := 20
const CARD_DESC_FONT_BOLD_PX := 21

var _cost_upgrade_flow_cb: Callable = Callable()

## 数字BBCode样式，用于控制卡牌描述中数字的显示方式
@export var number_bbcode_style: Card.NumberBbcodeStyle = Card.NumberBbcodeStyle.LISTING_UPGRADE

@export var card: Card : set = set_card

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
@onready var upgrade_level_panel: Panel = $UpgradeLevelPanel
@onready var upgrade_level_label: Label = $UpgradeLevelPanel/UpgradeLevel

var _player_modifiers: ModifierHandler
var _enemy_modifiers: ModifierHandler
var _combat_player_for_desc: Node = null

## 稀有度着色后的主面板样式
var main_panel_style_base: StyleBoxFlat
var main_panel_style_hover: StyleBoxFlat
var main_panel_style_drag: StyleBoxFlat

var _base_fonts_captured := false
var _base_cost_px: int
var _base_name_px: int
var _base_type_px: int
var _base_desc_normal_px: int
var _base_desc_bold_px: int
var _base_upgrade_px: int
var _font_sync_deferred := false
var freeze_font_sync_for_fly_phantom: bool = false
var _display_mana_cost_override: int = -1
var _combat_effective_mana_affordable: bool = true
var _upgrade_pick_bbcode_override: String = ""
var _desc_kw_meta_active: bool = false
var _desc_meta_signals_wired: bool = false


## 确保描述区的 meta 信号已连接
func _ensure_description_meta_signals() -> void:
	if _desc_meta_signals_wired or not is_instance_valid(description_label):
		return
	if not description_label.meta_hover_started.is_connected(_on_description_meta_hover_started):
		description_label.meta_hover_started.connect(_on_description_meta_hover_started)
	if not description_label.meta_hover_ended.is_connected(_on_description_meta_hover_ended):
		description_label.meta_hover_ended.connect(_on_description_meta_hover_ended)
	_desc_meta_signals_wired = true


## 描述区 meta 悬停开始
## 注意：不再直接显示 tooltip，而是标记状态，由 Hand._process 统一显示所有词条
func _on_description_meta_hover_started(meta: Variant) -> void:
	if not _upgrade_pick_bbcode_override.is_empty():
		return
	var s := str(meta)
	if not s.begins_with(CardKeywordBbcode.META_KW_PREFIX):
		return
	var kid := s.substr(CardKeywordBbcode.META_KW_PREFIX.length())
	if CardKeywordBbcode.get_keyword_tooltip_body_bbcode(kid, false).is_empty():
		return
	# 只标记状态，不直接发送 tooltip 显示事件
	# Hand._process 会检测到这个状态并显示该卡牌的所有词条
	_desc_kw_meta_active = true
	# 发送一个信号通知 Hand 需要刷新 tooltip，但不指定具体内容
	# 这样 Hand 会使用 get_keyword_tooltip_ids() 获取所有词条
	Events.card_keyword_tooltip_refresh_requested.emit(self)


## 描述区 meta 悬停结束
## 注意：不再直接隐藏 tooltip，由 Hand._process 统一控制显示/隐藏
func _on_description_meta_hover_ended(meta: Variant) -> void:
	if not str(meta).begins_with(CardKeywordBbcode.META_KW_PREFIX):
		return
	_desc_kw_meta_active = false
	# 发送刷新请求，让 Hand 决定是否隐藏
	Events.card_keyword_tooltip_refresh_requested.emit(self)


## 描述区 gui_input 处理：传递点击事件给父控件，但保留悬停事件用于词条链接
func _on_description_gui_input(event: InputEvent) -> void:
	# 对于点击事件，传递给父控件以便卡牌可以被拖动/打出
	if event is InputEventMouseButton:
		# 让 RichTextLabel 先处理（可能有点击链接的情况）
		# 然后向上传递
		if is_instance_valid(get_parent()):
			get_parent().gui_input.emit(event)


func _ready() -> void:
	_apply_pick_through_nested_controls()
	_capture_base_text_font_sizes_once()
	schedule_minimum_screen_font_sync()
	_ensure_description_meta_signals()


func is_description_kw_meta_active() -> bool:
	return _desc_kw_meta_active


## 强制重置描述区 meta 悬停状态（当卡牌不再是主悬停目标时调用）
func force_description_kw_meta_reset() -> void:
	if _desc_kw_meta_active:
		_desc_kw_meta_active = false
		Events.card_keyword_tooltip_hide.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		configure_cost_upgrade_for_flow(Callable())
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		if not freeze_font_sync_for_fly_phantom:
			schedule_minimum_screen_font_sync()


func schedule_minimum_screen_font_sync() -> void:
	if freeze_font_sync_for_fly_phantom:
		return
	if _font_sync_deferred:
		return
	_font_sync_deferred = true
	call_deferred("_deferred_apply_minimum_screen_fonts")


func _deferred_apply_minimum_screen_fonts() -> void:
	_font_sync_deferred = false
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_apply_minimum_screen_fonts()


func _capture_base_text_font_sizes_once() -> void:
	if _base_fonts_captured:
		return
	_base_fonts_captured = true
	_base_name_px = maxi(1, name_label.get_theme_font_size("font_size", "Label"))
	_base_type_px = maxi(1, type_label.get_theme_font_size("font_size", "Label"))
	_base_cost_px = maxi(1, cost.get_theme_font_size("font_size", "Label"))
	_base_desc_normal_px = CARD_DESC_FONT_NORMAL_PX
	_base_desc_bold_px = CARD_DESC_FONT_BOLD_PX
	if is_instance_valid(upgrade_level_label):
		_base_upgrade_px = maxi(1, upgrade_level_label.get_theme_font_size("font_size", "Label"))
	else:
		_base_upgrade_px = 16


func _canvas_max_scale_abs() -> float:
	var xf := get_global_transform_with_canvas()
	var sc := xf.get_scale()
	return maxf(0.0001, maxf(absf(sc.x), absf(sc.y)))


func _apply_minimum_screen_fonts() -> void:
	if not _base_fonts_captured:
		_capture_base_text_font_sizes_once()
	var s := _canvas_max_scale_abs()
	var min_design := ceili(float(MIN_SCREEN_CARD_TEXT_PX) / s)
	if is_instance_valid(cost):
		cost.add_theme_font_size_override("font_size", maxi(_base_cost_px, min_design))
	if is_instance_valid(name_label):
		name_label.add_theme_font_size_override("font_size", maxi(_base_name_px, min_design))
	if is_instance_valid(type_label):
		type_label.add_theme_font_size_override("font_size", maxi(_base_type_px, min_design))
	if is_instance_valid(description_label):
		var dn := maxi(_base_desc_normal_px, min_design)
		var db := maxi(_base_desc_bold_px, min_design)
		description_label.add_theme_font_size_override("normal_font_size", dn)
		description_label.add_theme_font_size_override("bold_font_size", db)
	if is_instance_valid(upgrade_level_label):
		upgrade_level_label.add_theme_font_size_override("font_size", maxi(_base_upgrade_px, min_design))


## 卡面内子控件不抢点击
func _apply_pick_through_nested_controls() -> void:
	if is_instance_valid(description_label):
		# 描述区需要接收鼠标事件来触发词条链接的 meta_hover 信号
		# 使用 STOP 确保能接收事件，但会在 _on_description_gui_input 中传递非悬停事件
		description_label.mouse_filter = Control.MOUSE_FILTER_STOP
		# 确保已连接 gui_input 信号来传递事件给父控件
		if not description_label.gui_input.is_connected(_on_description_gui_input):
			description_label.gui_input.connect(_on_description_gui_input)
	if is_instance_valid(cost):
		cost.mouse_filter = (
			Control.MOUSE_FILTER_STOP if _cost_upgrade_flow_cb.is_valid() else Control.MOUSE_FILTER_IGNORE
		)
	if is_instance_valid(name_label):
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(type_label):
		type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(upgrade_level_label):
		upgrade_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_card(value: Card) -> void:
	if value == null:
		return
	if not is_node_ready():
		await ready
	_upgrade_pick_bbcode_override = ""
	_display_mana_cost_override = -1
	_combat_effective_mana_affordable = true
	_combat_player_for_desc = null
	_desc_kw_meta_active = false
	configure_cost_upgrade_for_flow(Callable())
	_apply_pick_through_nested_controls()

	card = value
	_rebuild_main_panel_styles()
	_apply_rarity_panel_borders()
	_sync_from_card()
	schedule_minimum_screen_font_sync()


func set_display_mana_cost_override(value: int) -> void:
	_display_mana_cost_override = value
	if card:
		_sync_from_card()


func set_combat_effective_mana_affordable(affordable: bool) -> void:
	_combat_effective_mana_affordable = affordable
	_sync_cost_label_style()


func apply_modifier_context(
	player_modifiers: ModifierHandler, enemy_modifiers: ModifierHandler, combat_player: Node = null
) -> void:
	_player_modifiers = player_modifiers
	_enemy_modifiers = enemy_modifiers
	_combat_player_for_desc = combat_player
	_refresh_description_text()
	_sync_cost_label_style()


func _is_blade_card() -> bool:
	return card != null and card.id.begins_with("blade_")


func _is_status_card() -> bool:
	return card != null and card.type == Card.Type.STATUS


func _uses_haunted_gray_panels() -> bool:
	return card != null and card.id == "iron_wave"


func _rebuild_main_panel_styles() -> void:
	main_panel_style_base = _with_rarity_border(STYLE_BASE.duplicate() as StyleBoxFlat, card.rarity)
	main_panel_style_hover = _with_rarity_border(STYLE_HOVER.duplicate() as StyleBoxFlat, card.rarity)
	main_panel_style_drag = _with_rarity_border(STYLE_DRAG.duplicate() as StyleBoxFlat, card.rarity)
	if _is_status_card() or _uses_haunted_gray_panels():
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
	var frame_fill := STATUS_PANEL_BG if _is_status_card() or _uses_haunted_gray_panels() else Color(0, 0, 0, 0)
	frame_panel.add_theme_stylebox_override("panel", _inner_panel_style_opaque(r, frame_fill))
	var show_cost := card.cost >= 0
	cost_panel.visible = show_cost
	if show_cost:
		cost_panel.add_theme_stylebox_override("panel", _inner_panel_style_opaque(r, _inner_cost_fill()))
	else:
		cost_panel.remove_theme_stylebox_override("panel")
	title_panel.add_theme_stylebox_override("panel", _inner_panel_style_opaque(r, _inner_title_fill()))
	type_panel.add_theme_stylebox_override("panel", _inner_panel_style_opaque(r, _inner_type_fill()))
	upgrade_level_panel.add_theme_stylebox_override("panel", _inner_panel_style_opaque(r, _inner_title_fill()))


func set_upgrade_pick_description(bbcode: String) -> void:
	_upgrade_pick_bbcode_override = bbcode
	if is_instance_valid(description_label):
		description_label.bbcode_enabled = true
		description_label.mouse_filter = (
			Control.MOUSE_FILTER_STOP if not bbcode.is_empty() else Control.MOUSE_FILTER_IGNORE
		)
	_refresh_description_text()


func clear_upgrade_pick_description() -> void:
	_upgrade_pick_bbcode_override = ""
	configure_cost_upgrade_for_flow(Callable())
	_apply_pick_through_nested_controls()
	_refresh_description_text()


func configure_cost_upgrade_for_flow(cb: Callable) -> void:
	_cost_upgrade_flow_cb = cb
	if is_instance_valid(cost):
		if _cost_upgrade_flow_cb.is_valid():
			if not cost.gui_input.is_connected(_on_cost_label_gui_input):
				cost.gui_input.connect(_on_cost_label_gui_input)
		else:
			if cost.gui_input.is_connected(_on_cost_label_gui_input):
				cost.gui_input.disconnect(_on_cost_label_gui_input)
	_apply_pick_through_nested_controls()


func _on_cost_label_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _cost_upgrade_flow_cb.is_valid():
		_cost_upgrade_flow_cb.call()
		get_viewport().set_input_as_handled()


func _inner_cost_fill() -> Color:
	if _is_status_card() or _uses_haunted_gray_panels():
		return STATUS_PANEL_BG
	return BLADE_INNER_COST_BG if _is_blade_card() else INNER_COST_BG


func _inner_title_fill() -> Color:
	if _is_status_card() or _uses_haunted_gray_panels():
		return STATUS_PANEL_BG
	return BLADE_INNER_TITLE_BG if _is_blade_card() else INNER_TITLE_BG


func _inner_type_fill() -> Color:
	if _is_status_card() or _uses_haunted_gray_panels():
		return STATUS_PANEL_BG
	return BLADE_INNER_TYPE_BG if _is_blade_card() else INNER_TYPE_BG


func _inner_panel_style_opaque(rarity: Card.Rarity, fill: Color) -> StyleBoxFlat:
	var sb := STYLE_BASE.duplicate() as StyleBoxFlat
	sb.bg_color = fill
	sb.border_color = Card.RARITY_COLORS[rarity]
	return sb


## ============================================
## 子类必须覆盖的抽象方法
## ============================================

## 同步费用标签样式（子类实现不同逻辑）
func _sync_cost_label_style() -> void:
	pass


## 同步卡牌信息（子类实现不同逻辑）
func _sync_from_card() -> void:
	pass


## 刷新描述文本（子类实现不同逻辑）
func _refresh_description_text() -> void:
	pass


## 获取关键词 tooltip IDs（子类实现不同逻辑）
func get_keyword_tooltip_ids() -> PackedStringArray:
	return PackedStringArray()


## 添加固有前缀（子类实现不同逻辑）
func _prepend_intrinsic_line_bbcode(raw: String) -> String:
	return raw
