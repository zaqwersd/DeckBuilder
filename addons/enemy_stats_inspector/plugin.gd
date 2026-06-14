@tool
extends EditorPlugin

const INSPECTOR_SCRIPT := preload("res://addons/enemy_stats_inspector/enemy_stats_inspector_plugin.gd")

const PREVIEW_PROPERTIES: Array[StringName] = [
	&"health_bar_width",
	&"status_bar_offset",
	&"intent_ui_offset",
	&"max_health",
	&"art",
	&"art_scale",
	&"art_frames",
	&"art_frame_interval",
	&"editor_preview_action",
	&"editor_preview_intents",
]

var _inspector: EditorInspectorPlugin


func _enter_tree() -> void:
	_inspector = INSPECTOR_SCRIPT.new()
	add_inspector_plugin(_inspector)
	var inspector := get_editor_interface().get_inspector()
	if not inspector.property_edited.is_connected(_on_inspector_property_edited):
		inspector.property_edited.connect(_on_inspector_property_edited)
	if not get_editor_interface().scene_changed.is_connected(_on_editor_scene_changed):
		get_editor_interface().scene_changed.connect(_on_editor_scene_changed)


func _exit_tree() -> void:
	remove_inspector_plugin(_inspector)
	_inspector = null
	var inspector := get_editor_interface().get_inspector()
	if inspector.property_edited.is_connected(_on_inspector_property_edited):
		inspector.property_edited.disconnect(_on_inspector_property_edited)
	if get_editor_interface().scene_changed.is_connected(_on_editor_scene_changed):
		get_editor_interface().scene_changed.disconnect(_on_editor_scene_changed)


func _on_inspector_property_edited(property: StringName) -> void:
	if not _is_preview_property(property):
		return
	var stats := _stats_from_inspector_selection()
	if stats != null:
		stats.notify_battle_ui_preview_changed()


func _on_editor_scene_changed(_scene_root: Node) -> void:
	var root := get_editor_interface().get_edited_scene_root()
	if root == null:
		return
	_refresh_all_enemies_in_node(root)


func _stats_from_inspector_selection() -> Stats:
	var obj := get_editor_interface().get_inspector().get_edited_object()
	if obj is Stats:
		return obj as Stats
	if obj is Enemy:
		return (obj as Enemy).stats
	return null


func _is_preview_property(property: StringName) -> bool:
	var name := String(property)
	if name in PREVIEW_PROPERTIES:
		return true
	return name.ends_with("_offset") or name.ends_with("_width")


func _refresh_all_enemies_in_node(node: Node) -> void:
	if node is Enemy:
		(node as Enemy).refresh_editor_battle_preview()
	for child in node.get_children():
		_refresh_all_enemies_in_node(child)
