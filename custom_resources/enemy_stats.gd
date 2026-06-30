@tool
class_name EnemyStats
extends Stats

@export var ai: PackedScene
## 该敌人的战斗场景路径；为空则回退 `scenes/enemy/enemy.tscn`。
@export_file("*.tscn") var enemy_scene_path: String = ""
## 为 true 时 StatusBar / IntentUI 使用场景内手摆位置，忽略 stats 偏移字段。
@export var uses_scene_ui_layout: bool = false
## 战斗悬停 UI 与状态说明中的中文名。
@export var display_name: String = ""


func get_display_name() -> String:
	return display_name.strip_edges()


func get_enemy_scene() -> PackedScene:
	var path := SaveGameMigrations.remap_resource_path(enemy_scene_path.strip_edges())
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as PackedScene


## 战斗贴图缩放。`uses_scene_ui_layout` / `*_enemy.tscn` 请在场景里直接调 Sprite2D scale；仅旧布局生效。
@export var art_scale := Vector2(3, 3) : set = set_art_scale
## 多帧时在战斗中循环播放；少于 2 帧则仅用 `art`。
@export var art_frames: Array[Texture] = [] : set = set_art_frames
@export_range(0.05, 5.0, 0.05) var art_frame_interval: float = 0.5 : set = set_art_frame_interval


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


func setup_battle_visual(_enemy: Node) -> void:
	pass


## 供 `*_enemy.tscn` 编辑器预览：从 AI 取示例意图；行动名来自场景节点 `editor_preview_action`。
func build_editor_preview_intents(enemy: Node = null, preview_action: StringName = &"") -> Array[Intent]:
	if ai == null:
		return []
	return _preview_intents_from_ai(enemy, preview_action)


func _preview_intents_from_ai(enemy: Node, preview_action: StringName) -> Array[Intent]:
	var picker := ai.instantiate() as EnemyActionPicker
	if picker == null:
		return []
	var action := _resolve_preview_action(picker, preview_action)
	if action == null:
		picker.free()
		return []
	var out: Array[Intent] = []
	if Engine.is_editor_hint():
		out = _preview_intents_from_action_exports(action)
		picker.free()
		return out
	if enemy:
		action.enemy = enemy
		action.target = enemy
	action.update_planned_intents()
	for intent in action.get_planned_intents():
		if intent:
			out.append(intent.duplicate() as Intent)
	_apply_editor_preview_fallbacks(action, out)
	picker.free()
	return out


func _preview_intents_from_action_exports(action: EnemyAction) -> Array[Intent]:
	var out: Array[Intent] = []
	if action.intent != null:
		var dup := Intent.editor_materialize(action.intent)
		if dup != null:
			out.append(dup)
	_apply_editor_preview_fallbacks(action, out)
	return out


## 编辑器预览时 target 常为 Enemy 而非 Player，部分行动的 update_planned_intents 会跳过填数。
func _apply_editor_preview_fallbacks(action: EnemyAction, intents: Array[Intent]) -> void:
	var base_dmg := _read_export_int(action, &"damage", -1)
	for intent in intents:
		if intent == null or intent.kind != Intent.Kind.ATTACK:
			continue
		if Intent.editor_get_display_number(intent) != Intent.NUMBER_HIDDEN or not Intent.editor_get_current_text(intent).is_empty():
			continue
		if base_dmg < 0:
			continue
		var hits := _read_export_int(action, &"hit_count", -1)
		if hits < 0:
			hits = _read_export_int(action, &"segment_count", -1)
		if hits < 0:
			hits = _infer_attack_hits_from_action(action)
		intent.set_attack_segments_display(base_dmg, maxi(1, hits))


static func _read_export_int(node: Node, prop: StringName, fallback: int) -> int:
	if not node.get(prop) is int:
		return fallback
	return int(node.get(prop))


static func _infer_attack_hits_from_action(action: EnemyAction) -> int:
	if action.intent == null:
		return 1
	var parts := str(action.intent.get(&"base_text")).split("×")
	if parts.size() >= 2:
		var n := parts[0].strip_edges().to_int()
		if n > 0:
			return n
	return 1


func _resolve_preview_action(picker: EnemyActionPicker, preview_action: StringName) -> EnemyAction:
	var action_name := preview_action
	if picker is GhostSummonerEnemyAI:
		if action_name.is_empty():
			action_name = &"Strike5x3"
	elif picker is SpookEnemyAI:
		if action_name.is_empty():
			action_name = SpookEnemyAI.ACTION_INTENT1
	if not action_name.is_empty():
		var named := _find_named_action(picker, action_name)
		if named:
			return named
	for child in picker.get_children():
		if child is EnemyAction:
			return child as EnemyAction
	return null


static func _find_named_action(root: Node, action_name: StringName) -> EnemyAction:
	var needle := String(action_name)
	for child in root.get_children():
		if child.name == needle and child is EnemyAction:
			return child as EnemyAction
	return null
