class_name EventRoom
extends Control

@export var character_stats: CharacterStats
@export var run_stats: RunStats

var _is_run_reload := false


func set_run_reload(reload: bool) -> void:
	_is_run_reload = reload


func setup() -> void:
	pass
