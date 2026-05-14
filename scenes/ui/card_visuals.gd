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

## 卡面整体被 scale 缩小时，保证屏幕上文字至少该像素（逻辑字号 × 画布缩放 ≥ 此值）。
const MIN_SCREEN_CARD_TEXT_PX := 16

## 至少升级过一次的卡：名称与升级角标字色 #72d572
const UPGRADED_CARD_ACCENT := Color(0x72 / 255.0, 0xd5 / 255.0, 0x72 / 255.0, 1.0)
## 上述字色配套阴影色 #056f00；偏移 1px 至左下（shadow_offset_x/y）
const UPGRADED_FONT_OUTLINE := Color(0x05 / 255.0, 0x6f / 255.0, 0.0 / 255.0, 1.0)

## 卡面描述 RichTextLabel：正文字号；加粗（用于数字）比正文大 1px
const CARD_DESC_FONT_NORMAL_PX := 20
const CARD_DESC_FONT_BOLD_PX := 21

var _cost_upgrade_flow_cb: Callable = Callable()

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
@onready var upgrade_level_panel: Panel = $UpgradeLevelPanel
@onready var upgrade_level_label: Label = $UpgradeLevelPanel/UpgradeLevel

var _player_modifiers: ModifierHandler
var _enemy_modifiers: ModifierHandler
var _combat_player_for_desc: Node = null

## 稀有度着色后的主面板样式（供 CardUI / CardMenuUI 使用）
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
## 地图飞入牌库等：整卡 scale/位移每帧变化时跳过按画布缩放补字号，避免描述区错乱。
var freeze_font_sync_for_fly_phantom: bool = false
## 战斗手牌：左下角显示为「基础费 + 巨剑」等时的覆盖值；-1 表示用 card.cost。
var _display_mana_cost_override: int = -1
## 战斗：有效费用（override）下当前法力是否够付；与 `CardUpgradeUiColors` 黄/红一致。
var _combat_effective_mana_affordable: bool = true
## 非空时：卡面描述改为升级选词条专用 BBCode（可点 meta），用于营火升级流程。
var _upgrade_pick_bbcode_override: String = ""
## 鼠标正悬停在描述里 `kw:` 链接上（用于与「整卡词条 tooltip」互斥）。
var _desc_kw_meta_active: bool = false
var _desc_meta_signals_wired: bool = false

## 战斗手牌/战斗牌堆为 COMBAT；牌库/奖励/升级/事件选牌等为 LISTING（黄/灰/红词条数值色）。
var number_bbcode_style: Card.NumberBbcodeStyle = Card.NumberBbcodeStyle.LISTING_UPGRADE


func _ready() -> void:
	_apply_pick_through_nested_controls()
	_capture_base_text_font_sizes_once()
	schedule_minimum_screen_font_sync()
	_ensure_description_meta_signals()


func is_description_kw_meta_active() -> bool:
	return _desc_kw_meta_active


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


## 卡面内子控件不抢点击，统一交给父级 CardVisuals / CardUI / CardMenuUI 处理出牌与选牌。
## 仅营火「升级选词条」模式需 STOP，才能收到 RichText 的 meta_clicked（ugp:）。
## 战斗描述里的 kw: 链接不要用 STOP：否则会截获 gui_input，描述区无法拖动/出牌；词条说明由 Hand 整卡悬停 + Events 处理。
func _apply_pick_through_nested_controls() -> void:
	if is_instance_valid(description_label):
		var need_stop := not _upgrade_pick_bbcode_override.is_empty()
		description_label.mouse_filter = (
			Control.MOUSE_FILTER_STOP if need_stop else Control.MOUSE_FILTER_IGNORE
		)
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
	if card and number_bbcode_style == Card.NumberBbcodeStyle.COMBAT_PILES_AND_HAND:
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


## common_cards 等：与「恶灵」卡面相同的灰底面板（非状态牌也可用）
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


func _sync_cost_label_style() -> void:
	if not is_instance_valid(cost) or card == null:
		return
	if number_bbcode_style == Card.NumberBbcodeStyle.COMBAT_PILES_AND_HAND:
		if card.cost >= 0:
			var display_cost := card.cost
			if _display_mana_cost_override >= 0:
				display_cost = _display_mana_cost_override
			if not _combat_effective_mana_affordable:
				cost.add_theme_color_override(
					"font_color", CardUpgradeUiColors.color_bb_negative_removable()
				)
			elif display_cost > card.cost:
				cost.add_theme_color_override("font_color", CardUpgradeUiColors.color_bb_value())
			else:
				cost.add_theme_color_override("font_color", Color.WHITE)
		return
	if card.cost >= 0 and card.should_visualize_cost_as_upgradeable():
		cost.add_theme_color_override("font_color", CardUpgradeUiColors.color_bb_value())
	else:
		cost.remove_theme_color_override("font_color")


func _sync_from_card() -> void:
	var dc := card.cost
	if _display_mana_cost_override >= 0:
		dc = _display_mana_cost_override
	if dc >= 0:
		cost.text = str(dc)
	else:
		cost.text = ""
	_sync_cost_label_style()
	icon.texture = card.icon
	name_label.text = card.get_display_name()
	type_label.text = TYPE_DISPLAY.get(card.type, "")
	if number_bbcode_style == Card.NumberBbcodeStyle.LISTING_UPGRADE:
		if card.get_total_upgrade_count() > 0:
			name_label.add_theme_color_override("font_color", UPGRADED_CARD_ACCENT)
			name_label.add_theme_color_override("font_shadow_color", UPGRADED_FONT_OUTLINE)
			name_label.add_theme_constant_override("shadow_offset_x", -1)
			name_label.add_theme_constant_override("shadow_offset_y", 1)
			name_label.add_theme_constant_override("shadow_outline_size", 1)
		else:
			name_label.remove_theme_color_override("font_color")
			name_label.remove_theme_color_override("font_shadow_color")
			name_label.remove_theme_constant_override("shadow_offset_x")
			name_label.remove_theme_constant_override("shadow_offset_y")
			name_label.remove_theme_constant_override("shadow_outline_size")
		type_label.remove_theme_color_override("font_color")
	else:
		if card.get_total_upgrade_count() > 0:
			name_label.add_theme_color_override("font_color", UPGRADED_CARD_ACCENT)
			name_label.add_theme_color_override("font_shadow_color", UPGRADED_FONT_OUTLINE)
			name_label.add_theme_constant_override("shadow_offset_x", -1)
			name_label.add_theme_constant_override("shadow_offset_y", 1)
			name_label.add_theme_constant_override("shadow_outline_size", 1)
		else:
			name_label.add_theme_color_override("font_color", Color.WHITE)
			name_label.remove_theme_color_override("font_shadow_color")
			name_label.remove_theme_constant_override("shadow_offset_x")
			name_label.remove_theme_constant_override("shadow_offset_y")
			name_label.remove_theme_constant_override("shadow_outline_size")
		type_label.add_theme_color_override("font_color", Color.WHITE)
	_sync_upgrade_badge()
	_apply_description_default_color_for_style()
	_refresh_description_text()


func _sync_upgrade_badge() -> void:
	if not is_instance_valid(upgrade_level_panel) or not is_instance_valid(upgrade_level_label) or card == null:
		return
	var n := card.get_total_upgrade_count()
	upgrade_level_panel.visible = n > 0
	if n > 0:
		upgrade_level_label.text = "%d↑" % n
		upgrade_level_label.add_theme_color_override("font_color", UPGRADED_CARD_ACCENT)
		upgrade_level_label.add_theme_color_override("font_shadow_color", UPGRADED_FONT_OUTLINE)
		upgrade_level_label.add_theme_constant_override("shadow_offset_x", -1)
		upgrade_level_label.add_theme_constant_override("shadow_offset_y", 1)
		upgrade_level_label.add_theme_constant_override("shadow_outline_size", 1)
	else:
		upgrade_level_label.remove_theme_color_override("font_color")
		upgrade_level_label.remove_theme_color_override("font_shadow_color")
		upgrade_level_label.remove_theme_constant_override("shadow_offset_x")
		upgrade_level_label.remove_theme_constant_override("shadow_offset_y")
		upgrade_level_label.remove_theme_constant_override("shadow_outline_size")


func _apply_description_default_color_for_style() -> void:
	if not is_instance_valid(description_label):
		return
	if number_bbcode_style == Card.NumberBbcodeStyle.COMBAT_PILES_AND_HAND:
		description_label.add_theme_color_override("default_color", Color.WHITE)
	else:
		description_label.remove_theme_color_override("default_color")


func _prepend_intrinsic_line_bbcode(raw: String) -> String:
	if card == null or not card.intrinsic:
		return raw
	var prepend := false
	var kw_line := ""
	if number_bbcode_style == Card.NumberBbcodeStyle.COMBAT_PILES_AND_HAND:
		if card.should_show_intrinsic_keyword_in_combat_description():
			prepend = true
			kw_line = "[color=#ffffff][url=kw:intrinsic]固有。[/url][/color]"
	else:
		prepend = true
		kw_line = (
			"[color=%s][url=kw:intrinsic]固有。[/url][/color]" % CardUpgradeUiColors.BB_INACTIVE_KEYWORD
		)
		if card.id == "blade_overwhelming" and card.is_upgrade_track_maxed("intrinsic_line"):
			kw_line = "[color=#ffffff][url=kw:intrinsic]固有。[/url][/color]"
	if prepend:
		return kw_line + "[br]" + raw
	return raw


func _ensure_description_meta_signals() -> void:
	if _desc_meta_signals_wired or not is_instance_valid(description_label):
		return
	if not description_label.meta_hover_started.is_connected(_on_description_meta_hover_started):
		description_label.meta_hover_started.connect(_on_description_meta_hover_started)
	if not description_label.meta_hover_ended.is_connected(_on_description_meta_hover_ended):
		description_label.meta_hover_ended.connect(_on_description_meta_hover_ended)
	_desc_meta_signals_wired = true


func _on_description_meta_hover_started(meta: Variant) -> void:
	if not _upgrade_pick_bbcode_override.is_empty():
		return
	var s := str(meta)
	if not s.begins_with(CardKeywordBbcode.META_KW_PREFIX):
		return
	var kid := s.substr(CardKeywordBbcode.META_KW_PREFIX.length())
	if CardKeywordBbcode.get_keyword_tooltip_body_bbcode(kid, false).is_empty():
		return
	_desc_kw_meta_active = true
	Events.card_keyword_tooltip_show.emit(PackedStringArray([kid]), description_label)


func _on_description_meta_hover_ended(meta: Variant) -> void:
	if not str(meta).begins_with(CardKeywordBbcode.META_KW_PREFIX):
		return
	_desc_kw_meta_active = false
	Events.card_keyword_tooltip_hide.emit()


func _refresh_description_text() -> void:
	if card == null:
		return
	if not _upgrade_pick_bbcode_override.is_empty():
		Card.push_visual_number_bbcode_style(Card.NumberBbcodeStyle.LISTING_UPGRADE)
		description_label.text = CardKeywordBbcode.wrap_ascii_digit_runs_bold(
			CardKeywordBbcode.inject_keywords(_upgrade_pick_bbcode_override)
		)
		Card.pop_visual_number_bbcode_style()
		_apply_pick_through_nested_controls()
		_apply_description_default_color_for_style()
		return
	Card.push_visual_number_bbcode_style(number_bbcode_style)
	# 检查敌人修饰器是否仍然有效（敌人可能已死亡）
	var valid_enemy_modifiers := _enemy_modifiers if is_instance_valid(_enemy_modifiers) else null
	var raw := _prepend_intrinsic_line_bbcode(
		card.get_updated_visual_description_bbcode(
			_player_modifiers, valid_enemy_modifiers, _combat_player_for_desc
		)
	)
	Card.pop_visual_number_bbcode_style()
	description_label.text = CardKeywordBbcode.wrap_ascii_digit_runs_bold(CardKeywordBbcode.inject_keywords(raw))
	_apply_pick_through_nested_controls()
	_ensure_description_meta_signals()
	_apply_description_default_color_for_style()


## 当前卡面描述里是否含有可说明词条（与注入的「虚无」「消耗」一致），供手牌整张重合时显示 tooltip。
func get_keyword_tooltip_ids() -> PackedStringArray:
	if card == null:
		return PackedStringArray()
	Card.push_visual_number_bbcode_style(number_bbcode_style)
	# 检查敌人修饰器是否仍然有效（敌人可能已死亡）
	var valid_enemy_modifiers := _enemy_modifiers if is_instance_valid(_enemy_modifiers) else null
	var raw := _prepend_intrinsic_line_bbcode(
		card.get_updated_visual_description_bbcode(
			_player_modifiers, valid_enemy_modifiers, _combat_player_for_desc
		)
	)
	Card.pop_visual_number_bbcode_style()
	var ids := CardKeywordBbcode.collect_tooltip_ids_from_raw_description(raw)
	if card.intrinsic:
		var need_intrinsic_tt := false
		if number_bbcode_style == Card.NumberBbcodeStyle.COMBAT_PILES_AND_HAND:
			need_intrinsic_tt = card.should_show_intrinsic_keyword_in_combat_description()
		else:
			need_intrinsic_tt = true
		if need_intrinsic_tt:
			var has_intrinsic_id := false
			for i in range(ids.size()):
				if ids[i] == "intrinsic":
					has_intrinsic_id = true
					break
			if has_intrinsic_id:
				return ids
			var with_kw := PackedStringArray()
			with_kw.append("intrinsic")
			for i in range(ids.size()):
				with_kw.append(ids[i])
			return with_kw
	return ids
