@tool
extends VBoxContainer

const ENEMY_SCENE := preload("res://scenes/enemy/enemy.tscn")

var _stats: EnemyStats
var _viewport: SubViewport
var _enemy: Enemy
var _hint_label: Label


func setup(stats: EnemyStats) -> void:
	_disconnect_stats()
	_stats = stats
	_build_if_needed()
	_refresh()
	if is_instance_valid(_stats) and not _stats.changed.is_connected(_refresh):
		_stats.changed.connect(_refresh)


func _disconnect_stats() -> void:
	if is_instance_valid(_stats) and _stats.changed.is_connected(_refresh):
		_stats.changed.disconnect(_refresh)


func _exit_tree() -> void:
	_disconnect_stats()


func _build_if_needed() -> void:
	if _viewport != null:
		return
	_hint_label = Label.new()
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.text = "战斗 UI 预览：拖动上方 Battle UI 偏移后此处与战斗布局场景同步更新。"
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

	var anchor := Node2D.new()
	anchor.position = Vector2(260, 230)
	_viewport.add_child(anchor)

	_enemy = ENEMY_SCENE.instantiate() as Enemy
	anchor.add_child(_enemy)


func _refresh() -> void:
	if not is_instance_valid(_stats) or not is_instance_valid(_enemy):
		return
	if _enemy.stats != _stats:
		_enemy.stats = _stats
	_enemy.refresh_editor_battle_preview()
	_update_hint_label()


func _update_hint_label() -> void:
	if not is_instance_valid(_stats) or _hint_label == null:
		return
	_hint_label.text = (
			"战斗 UI 预览（与 `battles/*.tscn` 内一致）\n"
			+ "血条宽 %d px · 状态栏偏移 %s · 意图偏移 %s · 示例行动 %s"
			% [
				_stats.health_bar_width,
				_stats.status_bar_offset,
				_stats.intent_ui_offset,
				_stats.editor_preview_action if not _stats.editor_preview_action.is_empty() else "（AI 首个行动）",
			]
		)
