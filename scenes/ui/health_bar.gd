@tool
class_name HealthBar
extends HealthUI

const OUTLINE_COLOR := Color(0, 0, 0, 0.85)

## 血条区域高度（与场景中 BarHost 高度一致）
const BAR_HOST_HEIGHT := 10.0
## 与 `health_bar.tscn` 内 BarHost 默认宽度一致；未在场景中覆盖时不应作为权威宽度。
const DEFAULT_PACKED_HOST_WIDTH := 80
## 格挡图标区域大小（贴齐血条左缘，向左伸出）
const BLOCK_BADGE_SIZE := Vector2(25, 25)

## 在默认贴齐血条左缘、垂直居中的基础上再平移（像素）。请在场景树选中
## 「StatusBar → HealthRow」（HealthBar 根节点）后在检查器里改，不要改 BlockBadge 的 position（会被脚本覆盖）。
@export var block_badge_offset: Vector2 = Vector2.ZERO

@onready var bar_host: Control = $BarHost
@onready var block_badge: Control = $BarHost/BlockBadge
@onready var block_value_label: Label = $BarHost/BlockBadge/BlockValueLabel
@onready var hp_bar: ProgressBar = $BarHost/HPBar
@onready var _health_label: Label = $BarHost/HealthLabel
@onready var _max_health_label: Label = $BarHost/MaxHealthLabel

var _bar_width: int = 80
var _bar_width_saved_in_scene := false
var _applying_from_container := false

var _fill_red: StyleBoxFlat
var _fill_silver: StyleBoxFlat
var _track: StyleBoxFlat
var _theme_ready := false


static func normalize_bar_width(value: int) -> int:
	return maxi(value, 1)


static func clamp_bar_width(value: int) -> int:
	return normalize_bar_width(value)


## 读 StatusBar 容器宽度：仅场景布局敌人有效。
static func read_status_bar_container_width(status_bar: Control) -> int:
	if status_bar == null:
		return 0
	if status_bar is StatusBar and status_bar.has_method("uses_scene_container_width"):
		var sb := status_bar as StatusBar
		if not sb.uses_scene_container_width():
			return 0
		return sb.get_target_width()
	return maxi(int(roundf(status_bar.size.x)), 0)


## 由 StatusBar 拉伸同步；检查器可查看，一般无需手改。
@export var bar_width: int = 80:
	set(value):
		var normalized: int = HealthBar.normalize_bar_width(value)
		if _bar_width == normalized:
			return
		_bar_width = normalized
		_bar_width_saved_in_scene = true
		_apply_bar_width_to_host()
	get:
		return _bar_width


func ensure_theme_ready() -> void:
	var hp_bar_node := _get_hp_bar()
	var health_label_node := _get_health_label()
	var block_badge_node := _get_block_badge()
	var block_label_node := _get_block_value_label()
	if hp_bar_node == null or health_label_node == null or block_badge_node == null:
		return
	if _track == null:
		_track = StyleBoxFlat.new()
		_track.bg_color = Color(0.07, 0.07, 0.08, 1.0)
		_track.set_corner_radius_all(0)
	if _fill_red == null:
		_fill_red = StyleBoxFlat.new()
		_fill_red.bg_color = Color(0.945, 0.161, 0.2, 1.0)
		_fill_red.set_corner_radius_all(0)
	if _fill_silver == null:
		_fill_silver = StyleBoxFlat.new()
		_fill_silver.bg_color = Color(0.78, 0.8, 0.84, 1.0)
		_fill_silver.set_corner_radius_all(0)

	hp_bar_node.add_theme_stylebox_override("background", _track)
	hp_bar_node.add_theme_stylebox_override("fill", _fill_red)
	var max_lbl := _get_max_health_label()
	if max_lbl != null:
		max_lbl.visible = false
	_apply_label_outline(health_label_node)
	if block_label_node:
		_apply_label_outline(block_label_node)

	block_badge_node.custom_minimum_size = BLOCK_BADGE_SIZE
	hp_bar_node.z_index = 0
	health_label_node.z_index = 1
	block_badge_node.z_index = 2
	_reposition_block_badge()
	_theme_ready = true


func _enter_tree() -> void:
	var parent_ctrl := get_parent() as Control
	if parent_ctrl is StatusBar:
		if (parent_ctrl as StatusBar).uses_scene_container_width():
			call_deferred("apply_scene_fill_layout")
		return
	_hook_status_bar_container()
	call_deferred("_sync_from_status_bar_container")


func _get_minimum_size() -> Vector2:
	var ms := super.get_minimum_size()
	if get_parent() is StatusBar and (get_parent() as StatusBar).uses_scene_container_width():
		return Vector2(0.0, ms.y)
	return ms


func _exit_tree() -> void:
	_unhook_status_bar_container()


func _hook_status_bar_container() -> void:
	var parent_ctrl := get_parent() as Control
	if parent_ctrl == null:
		return
	if not parent_ctrl.resized.is_connected(_sync_from_status_bar_container):
		parent_ctrl.resized.connect(_sync_from_status_bar_container)


func _unhook_status_bar_container() -> void:
	var parent_ctrl := get_parent() as Control
	if parent_ctrl != null and parent_ctrl.resized.is_connected(_sync_from_status_bar_container):
		parent_ctrl.resized.disconnect(_sync_from_status_bar_container)


func _sync_from_status_bar_container() -> void:
	if _applying_from_container:
		return
	var parent_ctrl := get_parent() as Control
	if parent_ctrl == null:
		return
	if parent_ctrl is StatusBar and (parent_ctrl as StatusBar).uses_scene_container_width():
		apply_scene_fill_layout()
		return
	var w := read_status_bar_container_width(parent_ctrl)
	if w > 0:
		apply_width_from_status_bar_container(w)


func _ready() -> void:
	ensure_theme_ready()
	call_deferred("_sync_from_status_bar_container")


func has_saved_bar_width() -> bool:
	return _bar_width_saved_in_scene


func _uses_scene_fill_layout() -> bool:
	var parent_sb := get_parent() as StatusBar
	return parent_sb != null and parent_sb.uses_scene_container_width()


## 场景布局：血条宽度随 StatusBar 外框（布局填满），不用固定像素宽。
func apply_scene_fill_layout() -> void:
	if not _uses_scene_fill_layout():
		return
	_applying_from_container = true
	custom_minimum_size = Vector2(0.0, BAR_HOST_HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var host := _get_bar_host()
	if host != null:
		host.custom_minimum_size = Vector2(0.0, BAR_HOST_HEIGHT)
		host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		host.clip_contents = false
	_reposition_block_badge()
	if Engine.is_editor_hint():
		queue_redraw()
	else:
		queue_sort()
	_applying_from_container = false


## StatusBar 改宽时调用（非场景布局仍用固定像素宽）。
func apply_width_from_status_bar_container(width: int) -> void:
	if _applying_from_container or width <= 0:
		return
	if _uses_scene_fill_layout():
		apply_scene_fill_layout()
		var parent_sb := get_parent() as StatusBar
		if parent_sb != null:
			_bar_width = parent_sb.read_canvas_width()
		return
	_applying_from_container = true
	_bar_width = width
	_apply_layout_width(width)
	if Engine.is_editor_hint():
		notify_property_list_changed()
	_applying_from_container = false


func commit_bar_width_to_host(stats_fallback_width: int = 0) -> void:
	var parent_ctrl := get_parent() as Control
	if parent_ctrl is StatusBar and parent_ctrl.has_method("uses_scene_container_width"):
		var sb := parent_ctrl as StatusBar
		if sb.uses_scene_container_width():
			apply_scene_fill_layout()
			var w := sb.read_canvas_width()
			if w > 0:
				_bar_width = w
			return
	var from_container := 0
	if parent_ctrl is StatusBar and parent_ctrl.has_method("uses_scene_container_width"):
		if (parent_ctrl as StatusBar).uses_scene_container_width():
			from_container = read_status_bar_container_width(parent_ctrl)
	if from_container > 0:
		_bar_width = from_container
	else:
		_ingest_unsaved_bar_width(stats_fallback_width)
	_apply_bar_width_to_host()


func _ingest_unsaved_bar_width(stats_fallback_width: int = 0) -> void:
	if _bar_width_saved_in_scene:
		return
	var host := _get_bar_host()
	var host_w := 0
	if host != null:
		host_w = normalize_bar_width(int(roundf(host.custom_minimum_size.x)))
	if host_w > 1 and host_w != DEFAULT_PACKED_HOST_WIDTH:
		_bar_width = host_w
		return
	var fallback := normalize_bar_width(stats_fallback_width)
	if fallback > 1:
		_bar_width = fallback
		return
	if host_w > 0:
		_bar_width = host_w


func get_authoritative_bar_width(stats_fallback_width: int = 0) -> int:
	commit_bar_width_to_host(stats_fallback_width)
	return _bar_width


func ingest_bar_host_width_from_scene() -> void:
	var host_w: int = read_bar_host_width()
	if host_w <= 0:
		return
	if _bar_width == host_w:
		return
	_bar_width = host_w
	notify_property_list_changed()


func _apply_bar_width_to_host() -> void:
	_apply_layout_width(_bar_width)


func _apply_layout_width(width: int) -> void:
	var w := float(maxi(width, 1))
	var parent_sb := get_parent() as StatusBar
	var scene_layout := parent_sb != null and parent_sb.uses_scene_container_width()
	if scene_layout:
		custom_minimum_size = Vector2(0.0, BAR_HOST_HEIGHT)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		custom_minimum_size = Vector2(w, BAR_HOST_HEIGHT)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size.x = w
	var host := _get_bar_host()
	if host == null:
		return
	host.custom_minimum_size = Vector2(w, BAR_HOST_HEIGHT)
	host.size = Vector2(w, BAR_HOST_HEIGHT)
	host.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	host.clip_contents = false
	var hp_label := _get_health_label()
	if hp_label != null:
		hp_label.clip_text = false
		hp_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_reposition_block_badge()
	if Engine.is_editor_hint():
		queue_redraw()
	else:
		queue_sort()


func _get_bar_host() -> Control:
	if is_instance_valid(bar_host):
		return bar_host
	return get_node_or_null("BarHost") as Control


func _get_hp_bar() -> ProgressBar:
	if is_instance_valid(hp_bar):
		return hp_bar
	var host := _get_bar_host()
	if host == null:
		return null
	return host.get_node_or_null("HPBar") as ProgressBar


func _get_health_label() -> Label:
	if is_instance_valid(_health_label):
		return _health_label
	var host := _get_bar_host()
	if host == null:
		return null
	return host.get_node_or_null("HealthLabel") as Label


func _get_max_health_label() -> Label:
	if is_instance_valid(_max_health_label):
		return _max_health_label
	var host := _get_bar_host()
	if host == null:
		return null
	return host.get_node_or_null("MaxHealthLabel") as Label


func _get_block_badge() -> Control:
	if is_instance_valid(block_badge):
		return block_badge
	var host := _get_bar_host()
	if host == null:
		return null
	return host.get_node_or_null("BlockBadge") as Control


func _get_block_value_label() -> Label:
	if is_instance_valid(block_value_label):
		return block_value_label
	var badge := _get_block_badge()
	if badge == null:
		return null
	return badge.get_node_or_null("BlockValueLabel") as Label


func read_bar_host_width() -> int:
	var host := _get_bar_host()
	if host != null:
		return normalize_bar_width(int(roundf(host.custom_minimum_size.x)))
	return normalize_bar_width(_bar_width)


func read_authoritative_bar_width() -> int:
	return get_authoritative_bar_width()


func _uses_scene_fill_from_context(stats: Stats) -> bool:
	if stats != null and stats is EnemyStats and not Stats.is_editor_placeholder(stats):
		return (stats as EnemyStats).uses_scene_ui_layout
	var parent_sb := get_parent()
	if parent_sb is StatusBar and (parent_sb as StatusBar).uses_scene_container_width():
		return true
	return false


func update_stats(stats: Stats) -> void:
	if stats == null:
		return
	ensure_theme_ready()
	if not _theme_ready:
		return
	var uses_scene := _uses_scene_fill_from_context(stats)
	if uses_scene:
		apply_scene_fill_layout()
	if Engine.is_editor_hint() and not Stats.is_editor_ui_usable(stats):
		return
	if not uses_scene:
		var host := _get_bar_host()
		if host != null:
			var bw := clamp_bar_width(stats.health_bar_width)
			_bar_width = bw
			_apply_layout_width(bw)
	_reposition_block_badge()

	var hp := _get_hp_bar()
	var hl := _get_health_label()
	var bb := _get_block_badge()
	var bvl := _get_block_value_label()
	var max_lbl := _get_max_health_label()
	if hp == null or hl == null:
		return

	var has_block := stats.block > 0
	if bb != null:
		bb.visible = has_block
	if bvl != null:
		bvl.text = str(stats.block)

	hp.max_value = maxf(1.0, float(stats.max_health))
	hp.value = clampf(float(stats.health), 0.0, hp.max_value)
	hp.add_theme_stylebox_override("fill", _fill_silver if has_block else _fill_red)

	if show_max_hp:
		hl.text = "%s/%s" % [stats.health, stats.max_health]
		if max_lbl != null:
			max_lbl.text = ""
			max_lbl.visible = false
	else:
		hl.text = str(stats.health)
		if max_lbl != null:
			max_lbl.text = ""
			max_lbl.visible = false


func _reposition_block_badge() -> void:
	var badge := _get_block_badge()
	if badge == null:
		return
	badge.layout_mode = 0
	badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
	badge.offset_left = 0.0
	badge.offset_top = 0.0
	badge.offset_right = 0.0
	badge.offset_bottom = 0.0
	var base := Vector2(-BLOCK_BADGE_SIZE.x, (BAR_HOST_HEIGHT - BLOCK_BADGE_SIZE.y) * 0.5)
	badge.position = base + block_badge_offset
	badge.size = BLOCK_BADGE_SIZE


static func _apply_label_outline(lbl: Label) -> void:
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
