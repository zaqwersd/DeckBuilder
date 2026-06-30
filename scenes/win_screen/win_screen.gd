class_name WinScreen
extends Control

const MAIN_MENU_PATH = "res://scenes/ui/main_menu.tscn"
const MESSAGE := "胜利！"

@export var character: CharacterStats : set = set_character

@onready var message: Label = %Message


func set_character(new_character: CharacterStats) -> void:
	character = new_character
	message.text = MESSAGE


func _on_main_menu_button_pressed() -> void:
	var run := get_tree().get_first_node_in_group("run") as Run
	if run:
		run.abandon_finished_run_to_main_menu()
	else:
		SaveGame.delete_data()
		MusicPlayer.stop_for_menu_transition()
		get_tree().change_scene_to_file(MAIN_MENU_PATH)
