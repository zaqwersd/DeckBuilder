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
@onready var area_2d: Area2D = $Area2D

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
	var s := str(meta)
	if not s.begins_with(CardKeywordBbcode.META_KW_PREFIX):
		return
	var kid := s.substr(CardKeywordBbcode.META_KW_PREFIX.length())
	if CardKeywordBbcode.get_keyword_tooltip_body_bbcode(kid, false).is_empty():
		return
	# 标记状态
	_desc_kw_meta_active = true
	
	var ids := get_keyword_tooltip_ids()
	if not ids.is_empty():
		if _upgrade_pick_bbcode_override.is_empty():
			# 非升级模式：发送信号给 Hand 处理
			Events.card_keyword_tooltip_refresh_requested.emit(self)
		else:
			# 升级模式：直接显示 tooltip
			Events.card_keyword_tooltip_show.emit(ids, self)


## 描述区 meta 悬停结束
## 注意：不再直接隐藏 tooltip，由 Hand._process 统一控制显示/隐藏
func _on_description_meta_hover_ended(meta: Variant) -> void:
	if not str(meta).begins_with(CardKeywordBbcode.META_KW_PREFIX):
		return
	_desc_kw_meta_active = false
	
	if _upgrade_pick_bbcode_override.is_empty():
		# 非升级模式：发送刷新请求给 Hand
		Events.card_keyword_tooltip_refresh_requested.emit(self)
	else:
		# 升级模式：延迟检查是否还在任何词条上，如果不在则隐藏
		call_deferred("_check_hide_tooltip_if_not_on_meta")


## 描述区 gui_input 处理
## 在升级预览模式下，description 直接接收点击，词条链接优先
func _on_description_gui_input(event: InputEvent) -> void:
	# 只在升级模式下处理（此时 description_label.mouse_filter = STOP）
	if _upgrade_pick_bbcode_override.is_empty():
		return
	
	# 处理点击事件 - 但让 RichTextLabel 的 meta 链接先处理
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 延迟一帧检查，让 RichTextLabel 的 meta_click 先处理
		call_deferred("_deferred_check_click")


## 延迟检查点击，确保 RichTextLabel 的 meta_click 先处理
func _deferred_check_click() -> void:
	# 如果不在词条链接上，才传递点击给父节点
	if not _desc_kw_meta_active:
		if is_instance_valid(get_parent()) and get_parent().has_method("_on_card_visuals_clicked"):
			get_parent()._on_card_visuals_clicked()


## 延迟检查是否需要隐藏 tooltip（升级模式下使用）
func _check_hide_tooltip_if_not_on_meta() -> void:
	if not _desc_kw_meta_active and not _upgrade_pick_bbcode_override.is_empty():
		Events.card_keyword_tooltip_hide.emit()


func _ready() -> void:
	_apply_pick_through_nested_controls()
	_ensure_card_text_alignments()
	_capture_base_text_font_sizes_once()
	schedule_minimum_screen_font_sync()
	_ensure_description_meta_signals()
	_setup_area_2d_mouse_handling()


## 卡面文案对齐仅应在场景与脚本中保持 center/center；不在此处改动的代码路径不应把 Label 改成左上对齐。
func _ensure_card_text_alignments() -> void:
	if is_instance_valid(cost):
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if is_instance_valid(name_label):
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if is_instance_valid(type_label):
		type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		type_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if is_instance_valid(upgrade_level_label):
		upgrade_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		upgrade_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if is_instance_valid(description_label):
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


## 去掉 [center]：该标签会缩小可排版宽度导致过早换行；行内居中由 RichTextLabel 对齐负责。
static func format_description_bbcode_for_wrap(bbcode: String) -> String:
	return bbcode.replace("[center]", "").replace("[/center]", "")


func _set_description_label_text(raw_bbcode: String) -> void:
	if not is_instance_valid(description_label):
		return
	var laid_out := format_description_bbcode_for_wrap(raw_bbcode)
	description_label.text = CardKeywordBbcode.wrap_ascii_digit_runs_bold(
		CardKeywordBbcode.inject_keywords(laid_out)
	)


func is_description_kw_meta_active() -> bool:
	return _desc_kw_meta_active


## 强制重置描述区 meta 悬停状态（当卡牌不再是主悬停目标时调用）
func force_description_kw_meta_reset() -> void:
	if _desc_kw_meta_active:
		_desc_kw_meta_active = false
		Events.card_keyword_tooltip_hide.emit()


## 设置 Area2D 鼠标事件处理
func _setup_area_2d_mouse_handling() -> void:
	if not is_instance_valid(area_2d):
		return
	area_2d.mouse_entered.connect(_on_area_2d_mouse_entered)
	area_2d.mouse_exited.connect(_on_area_2d_mouse_exited)
	area_2d.input_event.connect(_on_area_2d_input_event)


## 与 Area2D 内 CollisionShape2D 一致的全局轴对齐包围盒（鼠标命中/叠放判定以此为准）。
func get_pick_collision_global_rect() -> Rect2:
	if not is_instance_valid(area_2d):
		return get_global_rect()
	var cs := area_2d.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null or not cs.visible or cs.disabled or cs.shape == null:
		return get_global_rect()
	var shp := cs.shape as RectangleShape2D
	if shp == null:
		return get_global_rect()
	var half := shp.size * 0.5
	var xf := cs.global_transform
	var corners: Array[Vector2] = [
		xf * Vector2(-half.x, -half.y),
		xf * Vector2(half.x, -half.y),
		xf * Vector2(half.x, half.y),
		xf * Vector2(-half.x, half.y)
	]
	var min_x := corners[0].x
	var max_x := corners[0].x
	var min_y := corners[0].y
	var max_y := corners[0].y
	for i in range(1, 4):
		min_x = minf(min_x, corners[i].x)
		max_x = maxf(max_x, corners[i].x)
		min_y = minf(min_y, corners[i].y)
		max_y = maxf(max_y, corners[i].y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


func _on_area_2d_mouse_entered() -> void:
	# 通知父节点鼠标进入（用于 Hand 检测悬停）
	if is_instance_valid(get_parent()) and get_parent().has_method("_on_card_visuals_mouse_entered"):
		get_parent()._on_card_visuals_mouse_entered()


func _on_area_2d_mouse_exited() -> void:
	# 通知父节点鼠标离开
	if is_instance_valid(get_parent()) and get_parent().has_method("_on_card_visuals_mouse_exited"):
		get_parent()._on_card_visuals_mouse_exited()


func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# 处理点击事件
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 检查是否点击在词条链接上
		if _desc_kw_meta_active:
			return  # 词条链接优先
		# 通知父节点点击
		if is_instance_valid(get_parent()) and get_parent().has_method("_on_card_visuals_clicked"):
			get_parent()._on_card_visuals_clicked()


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
	## 飞行幽灵已在 pivot 后锁定字号；若本 deferred 是冻结前排队触发的，必须跳过，否则会按 tween 中途的缩放再算一遍，造成偶发极小字、排版挤在角上。
	if freeze_font_sync_for_fly_phantom:
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


## 飞行幽灵卡：在 pivot/尺寸就绪后强制算一次最小可读字号，再锁定，避免 tween scale 每帧触发 NOTIFICATION_TRANSFORM_CHANGED 把字改乱。
func apply_minimum_fonts_once_then_freeze_for_phantom() -> void:
	if not _base_fonts_captured:
		_capture_base_text_font_sizes_once()
	_apply_minimum_screen_fonts()
	freeze_font_sync_for_fly_phantom = true


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
## 默认使用 Area2D 处理鼠标事件，所有 Control 设为 IGNORE
## 但在升级预览模式（_upgrade_pick_bbcode_override 不为空）时，description 需要直接接收点击
func _apply_pick_through_nested_controls() -> void:
	var is_upgrade_mode := not _upgrade_pick_bbcode_override.is_empty()
	
	# description_label 设置
	if is_instance_valid(description_label):
		if is_upgrade_mode:
			# 升级模式：description 需要接收词条链接点击
			description_label.mouse_filter = Control.MOUSE_FILTER_STOP
			if not description_label.gui_input.is_connected(_on_description_gui_input):
				description_label.gui_input.connect(_on_description_gui_input)
		else:
			# 普通模式：设为 IGNORE，让 Area2D 处理
			description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if description_label.gui_input.is_connected(_on_description_gui_input):
				description_label.gui_input.disconnect(_on_description_gui_input)
	
	# 费用：升级流程里若挂了费用点击回调，需能接收点击（与描述区一致）
	if is_instance_valid(cost):
		if is_upgrade_mode and _cost_upgrade_flow_cb.is_valid():
			cost.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(name_label):
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(type_label):
		type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(upgrade_level_label):
		upgrade_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 升级模式下禁用 Area2D 输入，让 description 优先
	if is_instance_valid(area_2d):
		area_2d.input_pickable = not is_upgrade_mode


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
	var show_cost := not card.is_unplayable()
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
	_apply_pick_through_nested_controls()  # 重新应用鼠标设置
	if is_instance_valid(description_label):
		description_label.bbcode_enabled = true
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
	elif not _cost_upgrade_flow_cb.is_null():
		_cost_upgrade_flow_cb = Callable()


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
