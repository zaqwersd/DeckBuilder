@tool
extends VBoxContainer

const ENEMY_SCENE := preload("res://scenes/enemy/enemy.tscn")

var _stats: EnemyStats
var _viewport: SubViewport
var _preview_anchor: Node2D
var _enemy: Enemy
var _hint_label: Label
var _preview_scene_path: String = ""


func setup(stats: EnemyStats) -> void:
	_disconnect_stats()
	_stats = stats
	_build_if_needed()
	_refresh()
	if _stats_signals_available() and not _stats.changed.is_connected(_refresh):
		_stats.changed.connect(_refresh)


func _stats_signals_available() -> bool:
	return is_instance_valid(_stats) and _stats.has_method("get_enemy_scene")


func _disconnect_stats() -> void:
	if _stats_signals_available() and _stats.changed.is_connected(_refresh):
		_stats.changed.disconnect(_refresh)


func _exit_tree() -> void:
	_disconnect_stats()


func _build_if_needed() -> void:
	if _viewport != null:
		return
	_hint_label = Label.new()
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.text = "战斗 UI 预览：在 *_enemy.tscn 中调整 StatusBar / IntentUI 位置。"
	add_child(_hint_label)

	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = Vector2(0, 420)
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(520, 400)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = false
	container.add_child(_viewport)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.08, 0.09, 0.11, 1.0)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.offset_right = 520.0
	backdrop.offset_bottom = 400.0
	_viewport.add_child(backdrop)

	_preview_anchor = Node2D.new()
	_preview_anchor.position = Vector2(260, 230)
	_viewport.add_child(_preview_anchor)


func _resolve_preview_scene_path() -> String:
	if not is_instance_valid(_stats):
		return ENEMY_SCENE.resource_path
	var path := SaveGameMigrations.remap_resource_path(_stats.enemy_scene_path.strip_edges())
	if path.is_empty():
		return ENEMY_SCENE.resource_path
	return path


func _load_preview_packed_scene() -> PackedScene:
	var path := _resolve_preview_scene_path()
	if path == ENEMY_SCENE.resource_path:
		return ENEMY_SCENE
	if not ResourceLoader.exists(path):
		return ENEMY_SCENE
	var custom := load(path) as PackedScene
	if custom != null:
		return custom
	return ENEMY_SCENE


func _ensure_preview_enemy() -> void:
	var desired := _resolve_preview_scene_path()
	if desired != _preview_scene_path:
		if is_instance_valid(_enemy):
			_enemy.queue_free()
			_enemy = null
		_preview_scene_path = desired
	if not is_instance_valid(_enemy):
		_enemy = _load_preview_packed_scene().instantiate() as Enemy
		_preview_anchor.add_child(_enemy)


func _refresh() -> void:
	if not is_instance_valid(_stats):
		return
	_build_if_needed()
	_ensure_preview_enemy()
	if not is_instance_valid(_enemy):
		return
	if _enemy.stats != _stats:
		_enemy.stats = _stats
	if _enemy.has_method("refresh_editor_battle_preview"):
		Enemy.request_editor_battle_preview(_enemy)
	_update_hint_label()


func _update_hint_label() -> void:
	if not is_instance_valid(_stats) or _hint_label == null:
		return
	var layout_note := "场景布局" if _stats.uses_scene_ui_layout else "stats 偏移"
	var scene_note := _preview_scene_path.get_file() if not _preview_scene_path.is_empty() else "enemy.tscn"
	var width_note := "血条宽见场景 StatusBar.container_width"
	var action_note := "（AI 首个行动）"
	if is_instance_valid(_enemy):
		if not _enemy.editor_preview_action.is_empty():
			action_note = String(_enemy.editor_preview_action)
		var sb := _enemy.get_node_or_null("StatusBar") as StatusBar
		if sb != null:
			var w := sb.get_target_width()
			if w <= 0:
				w = sb.container_width
			if w > 0:
				width_note = "血条宽 %d px（场景 container_width）" % w
	_hint_label.text = (
			"战斗 UI 预览（%s · %s）\n" % [layout_note, scene_note]
			+ "%s · 示例行动 %s" % [width_note, action_note]
		)
