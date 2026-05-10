class_name HealthBar
extends HealthUI

const OUTLINE_COLOR := Color(0, 0, 0, 0.85)

## 血条区域高度（与场景中 BarHost 高度一致）
const BAR_HOST_HEIGHT := 10.0
## 格挡图标区域大小（贴齐血条左缘，向左伸出）
const BLOCK_BADGE_SIZE := Vector2(25, 25)

## 在默认贴齐血条左缘、垂直居中的基础上再平移（像素）。请在场景树选中
## 「StatsUI → Health」（HealthBar 根节点）后在检查器里改，不要改 BlockBadge 的 position（会被脚本覆盖）。
@export var block_badge_offset: Vector2 = Vector2.ZERO

## 血条可伸缩宽度区间（随最大生命在两者之间插值）
const BAR_WIDTH_MIN := 120
const BAR_WIDTH_MAX := 232
## 用于宽度插值的「典型」最大生命区间（可按项目数值再调）
const MAX_HP_FOR_MIN_WIDTH := 10.0
const MAX_HP_FOR_MAX_WIDTH := 70.0

@onready var bar_host: Control = %BarHost
@onready var block_badge: Control = %BlockBadge
@onready var block_value_label: Label = %BlockValueLabel
@onready var hp_bar: ProgressBar = %HPBar

var _fill_red: StyleBoxFlat
var _fill_silver: StyleBoxFlat
var _track: StyleBoxFlat


func _ready() -> void:
	_track = StyleBoxFlat.new()
	_track.bg_color = Color(0.07, 0.07, 0.08, 1.0)
	_track.set_corner_radius_all(0)

	_fill_red = StyleBoxFlat.new()
	_fill_red.bg_color = Color(0.945, 0.161, 0.2, 1.0)
	_fill_red.set_corner_radius_all(0)

	_fill_silver = StyleBoxFlat.new()
	_fill_silver.bg_color = Color(0.78, 0.8, 0.84, 1.0)
	_fill_silver.set_corner_radius_all(0)

	hp_bar.add_theme_stylebox_override("background", _track)
	hp_bar.add_theme_stylebox_override("fill", _fill_red)
	max_health_label.visible = false
	_apply_label_outline(health_label)
	_apply_label_outline(block_value_label)

	block_badge.custom_minimum_size = BLOCK_BADGE_SIZE
	_reposition_block_badge()


func update_stats(stats: Stats) -> void:
	var bw := _bar_width_for_max_hp(stats.max_health)
	bar_host.custom_minimum_size = Vector2(float(bw), BAR_HOST_HEIGHT)
	_reposition_block_badge()

	var has_block := stats.block > 0
	block_badge.visible = has_block
	block_value_label.text = str(stats.block)

	hp_bar.max_value = maxf(1.0, float(stats.max_health))
	hp_bar.value = clampf(float(stats.health), 0.0, hp_bar.max_value)
	hp_bar.add_theme_stylebox_override("fill", _fill_silver if has_block else _fill_red)

	if show_max_hp:
		health_label.text = "%s/%s" % [stats.health, stats.max_health]
	else:
		health_label.text = str(stats.health)
	max_health_label.text = ""


func _bar_width_for_max_hp(max_hp: int) -> int:
	var t := clampf(
		(float(max_hp) - MAX_HP_FOR_MIN_WIDTH) / maxf(0.001, MAX_HP_FOR_MAX_WIDTH - MAX_HP_FOR_MIN_WIDTH),
		0.0,
		1.0
	)
	return int(round(lerpf(float(BAR_WIDTH_MIN), float(BAR_WIDTH_MAX), t)))


func _reposition_block_badge() -> void:
	# 必须用「纯坐标」布局；若处于锚点/容器模式，引擎会在排序后改写 transform，
	# 容易出现 offset 正负表现异常或看起来不生效。
	# 0 = 编辑器里的「位置」布局；4.6 脚本侧无 Control.LAYOUT_MODE_POSITION 枚举名。
	block_badge.layout_mode = 0
	block_badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
	block_badge.offset_left = 0.0
	block_badge.offset_top = 0.0
	block_badge.offset_right = 0.0
	block_badge.offset_bottom = 0.0
	var base := Vector2(-BLOCK_BADGE_SIZE.x, (BAR_HOST_HEIGHT - BLOCK_BADGE_SIZE.y) * 0.5)
	block_badge.position = base + block_badge_offset
	block_badge.size = BLOCK_BADGE_SIZE


static func _apply_label_outline(lbl: Label) -> void:
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
