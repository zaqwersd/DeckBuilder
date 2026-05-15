class_name PauseMenu
extends CanvasLayer

signal save_and_quit

@onready var back_to_game_button: Button = %BackToGameButton
@onready var save_and_quit_button: Button = %SaveAndQuitButton


func _ready() -> void:
	back_to_game_button.pressed.connect(close)
	save_and_quit_button.pressed.connect(_on_save_and_quit_button_pressed)


func open() -> void:
	if visible:
		return
	show()
	get_tree().paused = true


func close() -> void:
	if not visible:
		return
	hide()
	get_tree().paused = false


func _on_save_and_quit_button_pressed() -> void:
	get_tree().paused = false
	save_and_quit.emit()
