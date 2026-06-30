@tool
class_name StatusBar
extends VBoxContainer

const META_BLOCK_INGEST := &"_status_bar_block_ingest"

## 悬停状态说明相对图标的水平侧：玩家 true（右侧），敌人请在场景中设为 false（左侧）
@export var status_tooltips_open_to_right: bool = true

## 与 2D 外框宽度同步（只写不读来撑大外框）。拖 StatusBar 左右边会自动更新此值。
@export_range(1, 4096, 1) var container_width: int = 100

@onready var health: HealthUI = $HealthRow

var _syncing_layout := false


func uses_scene_container_width() -> bool:
	if not _parent_is_node2d():
		return false
	var enemy := _find_enemy_owner()
	if enemy != null and _enemy_uses_scene_container_layout(enemy):
		return true
	return container_width != 100


func _enemy_uses_scene_container_layout(enemy: Enemy) -> bool:
	var path := enemy.get_scene_file_path()
	if path.is_empty():
		path = enemy.scene_file_path
	if path.ends_with("_enemy.tscn"):
		return true
	var stats_val: Variant = enemy.get(&"stats")
	if stats_val is EnemyStats:
		var es := stats_val as EnemyStats
		if Engine.is_editor_hint() and Stats.is_editor_placeholder(es):
			if enemy.has_method("_editor_resolved_stats"):
				var resolved := enemy.call("_editor_resolved_stats") as EnemyStats
				return resolved != null and resolved.uses_scene_ui_layout
			return false
		return es.uses_scene_ui_layout
	if enemy.has_method("uses_scene_ui_layout") and _enemy_script_methods_callable(enemy):
		return enemy.uses_scene_ui_layout()
	return false


func _enemy_script_methods_callable(enemy: Node) -> bool:
	if not Engine.is_editor_hint():
		return true
	if enemy.get_script() == null:
		return false
	return enemy.has_method("hide_immediate")


func is_applying_width() -> bool:
	return _syncing_layout or has_meta(META_BLOCK_INGEST)


func _find_enemy_owner() -> Enemy:
	var node := get_parent()
	while node != null:
		if node is Enemy:
			return node as Enemy
		node = node.get_parent()
	return null


func _parent_is_node2d() -> bool:
	var parent_node := get_parent()
	return parent_node != null and not (parent_node is Control)


func _get_minimum_size() -> Vector2:
	var bar_w := get_health_bar_layout_width()
	var health_ms := Vector2.ZERO
	var health_row := get_node_or_null("HealthRow") as Control
	if health_row != null:
		health_ms = health_row.get_combined_minimum_size()
	var status_h := _status_handler_height()
	var row_sep := float(get_theme_constant("separation"))
	var total_y := health_ms.y + status_h + (row_sep if status_h > 0.0 else 0.0)
	if bar_w > 0:
		return Vector2(float(bar_w), total_y)
	if uses_scene_container_width():
		return Vector2(0.0, total_y)
	return Vector2(health_ms.x, total_y)


func _status_handler_height() -> float:
	var sh := get_node_or_null("StatusHandler") as Control
	if sh == null:
		return 0.0
	return sh.get_combined_minimum_size().y


func get_health_bar_layout_width() -> int:
	var health_row := get_node_or_null("HealthRow") as HealthBar
	if health_row != null:
		if uses_scene_container_width():
			var canvas_w := read_canvas_width()
			if canvas_w > 0:
				return canvas_w
		return health_row.get_authoritative_bar_width(0)
	if uses_scene_container_width():
		return get_target_width()
	return 0


func _refresh_status_handler_layout() -> void:
	var sh := get_node_or_null("StatusHandler") as StatusHandler
	if sh == null:
		return
	sh.relayout_to_width(get_health_bar_layout_width())


func _ready() -> void:
	clip_contents = false
	alignment = ALIGNMENT_BEGIN
	var sh_node := get_node_or_null("StatusHandler")
	if sh_node is StatusHandler:
		(sh_node as StatusHandler).tooltips_open_to_right = status_tooltips_open_to_right
	var health_row := get_node_or_null("HealthRow") as Control
	if health_row != null and not health_row.resized.is_connected(_on_health_row_resized):
		health_row.resized.connect(_on_health_row_resized)
	if uses_scene_container_width():
		custom_minimum_size.x = 0.0
		if not resized.is_connected(_on_scene_layout_resized):
			resized.connect(_on_scene_layout_resized)
		call_deferred("_refresh_scene_layout")
	call_deferred("_refresh_status_handler_layout")


func _notification(what: int) -> void:
	if (
		not Engine.is_editor_hint()
		or not uses_scene_container_width()
		or is_applying_width()
	):
		return
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		call_deferred("_ingest_canvas_width_to_export")


## 只读 StatusBar 自身外框，绝不读子节点或 container_width 反推。
func read_canvas_width() -> int:
	var offset_w := int(roundf(absf(offset_right - offset_left)))
	if offset_w >= 1:
		return offset_w
	return maxi(int(roundf(size.x)), 0)


func get_target_width() -> int:
	var canvas_w := read_canvas_width()
	if canvas_w > 0:
		return canvas_w
	if container_width > 0:
		return container_width
	return 0


func read_container_width() -> int:
	return get_target_width()


func _ingest_canvas_width_to_export() -> void:
	if is_applying_width() or not uses_scene_container_width():
		return
	var w := read_canvas_width()
	if w <= 0:
		return
	if w != container_width:
		container_width = w
	_refresh_scene_layout()


func _on_health_row_resized() -> void:
	call_deferred("_refresh_status_handler_layout")


func _on_scene_layout_resized() -> void:
	if is_applying_width() or not uses_scene_container_width():
		return
	call_deferred("_ingest_canvas_width_to_export")


func apply_user_width(width: int) -> void:
	if not uses_scene_container_width() or width <= 0:
		return
	_syncing_layout = true
	set_meta(META_BLOCK_INGEST, true)
	container_width = width
	_push_export_width_to_canvas(width)
	_refresh_scene_layout()
	remove_meta(META_BLOCK_INGEST)
	_syncing_layout = false


func request_layout_sync() -> void:
	_refresh_scene_layout()


func sync_health_bar_to_container_width() -> void:
	_refresh_scene_layout()


func force_container_width(width: int) -> void:
	apply_user_width(width)


func _push_export_width_to_canvas(width: int) -> void:
	var fw := float(maxi(width, 1))
	if absf(offset_right - offset_left) >= 1.0 or absf(offset_left) > 0.01 or absf(offset_right) > 0.01:
		offset_right = offset_left + fw
	elif size.x >= 1.0 or Engine.is_editor_hint():
		size.x = fw


func _refresh_scene_layout() -> void:
	if not uses_scene_container_width() or _syncing_layout:
		return
	_syncing_layout = true
	set_meta(META_BLOCK_INGEST, true)

	var health_row := get_node_or_null("HealthRow") as HealthBar
	if health_row != null:
		health_row.apply_scene_fill_layout()
		(health_row as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		(health_row as Control).custom_minimum_size.x = 0.0

	var sh := get_node_or_null("StatusHandler") as Control
	if sh != null:
		sh.custom_minimum_size.x = 0.0
		sh.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		sh.size_flags_stretch_ratio = 0.0

	custom_minimum_size.x = 0.0
	queue_sort()

	remove_meta(META_BLOCK_INGEST)
	_syncing_layout = false
	_refresh_status_handler_layout()
	_notify_enemy_hover_name_sync()


func _notify_enemy_hover_name_sync() -> void:
	var enemy := _find_enemy_owner()
	if enemy == null or not enemy.has_method("_sync_scene_ui_hover_name"):
		return
	if not _enemy_script_methods_callable(enemy):
		return
	enemy.call_deferred("_sync_scene_ui_hover_name")


func _resolve_stats_for_ui(stats: Stats) -> Stats:
	if stats == null:
		return null
	if not Engine.is_editor_hint():
		return stats
	if Stats.is_editor_ui_usable(stats):
		return stats
	var enemy := _find_enemy_owner()
	if enemy != null and enemy.has_method("_editor_preview_stats"):
		return enemy.call("_editor_preview_stats") as Stats
	return null


func update_stats(stats: Stats) -> void:
	if uses_scene_container_width():
		_refresh_scene_layout()
	var apply_stats := _resolve_stats_for_ui(stats)
	if apply_stats == null:
		return
	var health_row := get_node_or_null("HealthRow") as HealthUI
	if health_row == null:
		return
	if health_row is HealthBar:
		(health_row as HealthBar).ensure_theme_ready()
	health_row.update_stats(apply_stats)
	health_row.visible = int(apply_stats.get(&"health")) > 0
	_refresh_status_handler_layout()
