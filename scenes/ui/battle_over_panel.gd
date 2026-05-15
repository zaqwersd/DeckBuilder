class_name BattleOverPanel
extends Panel

const MAIN_MENU = "res://scenes/ui/main_menu.tscn"

enum Type {WIN, LOSE}

@onready var label: Label = %Label
@onready var continue_button: Button = %ContinueButton
@onready var main_menu_button: Button = %MainMenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	continue_button.pressed.connect(func(): Events.battle_won.emit())
	main_menu_button.pressed.connect(get_tree().change_scene_to_file.bind(MAIN_MENU))
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
	show()
	get_tree().paused = true
