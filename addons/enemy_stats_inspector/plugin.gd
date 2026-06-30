@tool
extends EditorPlugin

const INSPECTOR_SCRIPT := preload("res://addons/enemy_stats_inspector/enemy_stats_inspector_plugin.gd")

const PREVIEW_PROPERTIES: Array[StringName] = [
	&"max_health",
	&"art",
	&"art_scale",
	&"art_frames",
	&"art_frame_interval",
	&"enemy_scene_path",
	&"uses_scene_ui_layout",
]

var _inspector: EditorInspectorPlugin


func _enter_tree() -> void:
	_inspector = INSPECTOR_SCRIPT.new()
	add_inspector_plugin(_inspector)
	var inspector := get_editor_interface().get_inspector()
	if not inspector.property_edited.is_connected(_on_inspector_property_edited):
		inspector.property_edited.connect(_on_inspector_property_edited)
	if not scene_changed.is_connected(_on_editor_scene_changed):
		scene_changed.connect(_on_editor_scene_changed)


func _exit_tree() -> void:
	remove_inspector_plugin(_inspector)
	_inspector = null
	var inspector := get_editor_interface().get_inspector()
	if inspector.property_edited.is_connected(_on_inspector_property_edited):
		inspector.property_edited.disconnect(_on_inspector_property_edited)
	if scene_changed.is_connected(_on_editor_scene_changed):
		scene_changed.disconnect(_on_editor_scene_changed)


func _on_inspector_property_edited(property: StringName) -> void:
	var obj := get_editor_interface().get_inspector().get_edited_object()
	if obj is Control:
		var ctrl := obj as Control
		if ctrl.name == "StatusBar" or ctrl is StatusBar:
			if ctrl is StatusBar:
				var sb := ctrl as StatusBar
				if sb.is_applying_width():
					return
				if sb.uses_scene_container_width():
					var prop := String(property)
					if prop == "container_width":
						sb.apply_user_width(sb.container_width)
					elif prop == "size" or prop.begins_with("offset_"):
						sb.call_deferred("_ingest_canvas_width_to_export")
				else:
					_request_enemy_preview(_find_enemy_ancestor(ctrl))
			return
		if ctrl.name == "IntentUI" or ctrl.name == "BarHost":
			_request_enemy_preview(_find_enemy_ancestor(ctrl))
			return
	if obj is HealthBar:
		_request_enemy_preview(_find_enemy_ancestor(obj))
		return
	if obj is Control:
		var ctrl := obj as Control
		if ctrl.name == "BarHost" or ctrl is HealthBar:
			_request_enemy_preview(_find_enemy_ancestor(ctrl))
			return
	if obj is Enemy:
		if String(property) == "editor_preview_action":
			_request_enemy_preview(obj as Enemy)
			return
		var estats := (obj as Enemy).stats
		if estats != null and _is_preview_property(property):
			estats.notify_battle_ui_preview_changed()
		return
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
	if name.begins_with("offset_") or name == &"size" or name == &"position" or name == &"container_width":
		return true
	return name.ends_with("_offset") or name.ends_with("_width")


func _refresh_all_enemies_in_node(node: Node) -> void:
	if node is Enemy:
		_request_enemy_preview(node)
	for child in node.get_children():
		_refresh_all_enemies_in_node(child)


static func _request_enemy_preview(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if not enemy is Enemy:
		return
	var scr: Script = enemy.get_script() as Script
	if scr == null or not scr is GDScript or not (scr as GDScript).is_tool():
		return
	var cb := Callable(enemy, "refresh_editor_battle_preview")
	if not cb.is_valid():
		return
	cb.call_deferred()


static func _find_enemy_ancestor(node: Node) -> Enemy:
	var current := node
	while current != null:
		if current is Enemy:
			return current as Enemy
		current = current.get_parent()
	return null
