@tool
class_name EnemyStats
extends Stats

@export var ai: PackedScene
## 战斗悬停 UI 与状态说明中的中文名。
@export var display_name: String = ""


func get_display_name() -> String:
	return display_name.strip_edges()


## 战斗贴图显示缩放（`enemy.tscn` 默认 3）；按敌人立绘在 .tres 中调整。
@export var art_scale := Vector2(3, 3) : set = set_art_scale
## 多帧时在战斗中循环播放；少于 2 帧则仅用 `art`。
@export var art_frames: Array[Texture] = [] : set = set_art_frames
@export_range(0.05, 5.0, 0.05) var art_frame_interval: float = 0.5 : set = set_art_frame_interval

@export_group("编辑器 UI 预览")
## 在 .tres 检查器与战斗布局场景中展示的示例行动（AI 场景里的节点名，如 Strike5x3、Intent1）。留空则取 AI 第一个子行动。
@export var editor_preview_action: StringName = &"" : set = set_editor_preview_action
## 若填写，则优先于 `editor_preview_action`，直接展示这些意图图标。
@export var editor_preview_intents: Array[Intent] = [] : set = set_editor_preview_intents


func set_art_scale(value: Vector2) -> void:
	if art_scale.is_equal_approx(value):
		return
	art_scale = value
	notify_battle_ui_preview_changed()


func set_art_frames(value: Array[Texture]) -> void:
	art_frames = value
	notify_battle_ui_preview_changed()


func set_art_frame_interval(value: float) -> void:
	var clamped := clampf(value, 0.05, 5.0)
	if is_equal_approx(art_frame_interval, clamped):
		return
	art_frame_interval = clamped
	notify_battle_ui_preview_changed()


func set_editor_preview_action(value: StringName) -> void:
	if editor_preview_action == value:
		return
	editor_preview_action = value
	notify_battle_ui_preview_changed()


func set_editor_preview_intents(value: Array[Intent]) -> void:
	editor_preview_intents = value
	notify_battle_ui_preview_changed()


func setup_battle_visual(_enemy: Node) -> void:
	pass


## 供战斗布局场景与 EnemyStats 检查器预览：复制意图资源并写入示例数字/文案。
func build_editor_preview_intents(enemy: Node = null) -> Array[Intent]:
	if not editor_preview_intents.is_empty():
		return _duplicate_intents(editor_preview_intents)
	if ai == null:
		return []
	return _preview_intents_from_ai(enemy)


func _duplicate_intents(source: Array[Intent]) -> Array[Intent]:
	var out: Array[Intent] = []
	for intent in source:
		if intent:
			out.append(intent.duplicate() as Intent)
	return out


func _preview_intents_from_ai(enemy: Node) -> Array[Intent]:
	var picker := ai.instantiate() as EnemyActionPicker
	if picker == null:
		return []
	var action := _resolve_preview_action(picker, enemy)
	if action == null:
		picker.free()
		return []
	if enemy:
		action.enemy = enemy
	action.update_planned_intents()
	var out: Array[Intent] = []
	for intent in action.get_planned_intents():
		if intent:
			out.append(intent.duplicate() as Intent)
	picker.free()
	return out


func _resolve_preview_action(picker: EnemyActionPicker, _enemy: Node) -> EnemyAction:
	if picker is GhostSummonerEnemyAI:
		var gs_ai := picker as GhostSummonerEnemyAI
		var action_name := editor_preview_action if not editor_preview_action.is_empty() else &"Strike5x3"
		gs_ai.assigned_action_name = action_name
		return gs_ai.get_action()
	if picker is SpookEnemyAI:
		var action_name := editor_preview_action if not editor_preview_action.is_empty() else SpookEnemyAI.ACTION_INTENT1
		return picker.get_node_or_null(String(action_name)) as EnemyAction
	if not editor_preview_action.is_empty():
		var named := picker.get_node_or_null(String(editor_preview_action)) as EnemyAction
		if named:
			return named
	for child in picker.get_children():
		if child is EnemyAction:
			return child as EnemyAction
	return null
