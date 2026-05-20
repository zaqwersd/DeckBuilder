extends Control

const RUN_SCENE = preload("res://scenes/run/run.tscn")
const MAIN_MENU_PATH := "res://scenes/ui/main_menu.tscn"
const BLADE_STATS := preload("res://characters/blade/blade.tres")

@export var run_startup: RunStartup

@onready var title: Label = %Title
@onready var max_health_label: Label = %MaxHealth
@onready var description: Label = %Description
@onready var starting_relic_icon: TextureRect = %StartingRelicIcon
@onready var starting_relic_name: Label = %StartingRelicName
@onready var starting_relic_desc: RichTextLabel = %StartingRelicDesc
@onready var character_portrait: TextureRect = %CharacterPortrait

var current_character: CharacterStats : set = set_current_character


func _ready() -> void:
	character_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_current_character(BLADE_STATS)


func set_current_character(new_character: CharacterStats) -> void:
	current_character = new_character
	title.text = current_character.character_name
	max_health_label.text = str(current_character.max_health)
	description.text = current_character.description
	character_portrait.texture = current_character.portrait
	_apply_starting_relic_display(new_character.starting_relic)


func _apply_starting_relic_display(relic: Relic) -> void:
	if relic == null:
		starting_relic_icon.texture = null
		starting_relic_name.text = ""
		starting_relic_desc.text = ""
		return
	starting_relic_icon.texture = relic.icon
	starting_relic_name.text = relic.relic_name
	starting_relic_desc.text = relic.get_tooltip()


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


func _on_start_button_pressed() -> void:
	print("开始新冒险：%s" % current_character.character_name)
	run_startup.type = RunStartup.Type.NEW_RUN
	run_startup.picked_character = current_character
	get_tree().change_scene_to_packed(RUN_SCENE)
