class_name BattleOverPanel
extends Panel

const MAIN_MENU = "res://scenes/ui/main_menu.tscn"

enum Type {WIN, LOSE}

@onready var label: Label = %Label
@onready var continue_button: Button = %ContinueButton
@onready var main_menu_button: Button = %MainMenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	continue_button.pressed.connect(_on_continue_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	Events.battle_over_screen_requested.connect(show_screen)


## 等飘字与命中音效播一段后再暂停并显示，避免结算盖住演出。
const BATTLE_OVER_DELAY_SEC := maxf(FloatingCombatNumber.DURATION + 0.12, 0.92)


func show_screen(text: String, type: Type) -> void:
	await get_tree().create_timer(BATTLE_OVER_DELAY_SEC).timeout
	if not is_inside_tree():
		return
	label.text = text
	continue_button.visible = type == Type.WIN
	main_menu_button.visible = type == Type.LOSE
	if type == Type.LOSE:
		var run := get_tree().get_first_node_in_group("run") as Run
		if run:
			run.mark_run_finished()
	show()
	get_tree().paused = true


func _on_continue_pressed() -> void:
	hide()
	get_tree().paused = false
	Events.battle_won.emit()


func _on_main_menu_pressed() -> void:
	var run := get_tree().get_first_node_in_group("run") as Run
	if run:
		run.abandon_finished_run_to_main_menu()
	else:
		SaveGame.delete_data()
		get_tree().paused = false
		MusicPlayer.stop_for_menu_transition()
		get_tree().change_scene_to_file(MAIN_MENU)
