@tool
extends EditorInspectorPlugin

const PREVIEW_PANEL := preload("res://addons/enemy_stats_inspector/enemy_stats_preview_panel.gd")


func _can_handle(object: Object) -> bool:
	return object is EnemyStats


func _parse_begin(object: Object) -> void:
	var panel := PREVIEW_PANEL.new()
	panel.setup(object as EnemyStats)
	add_custom_control(panel)
