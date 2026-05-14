extends Control

const CHAR_SELECTOR_SCENE := preload("res://scenes/ui/character_selector.tscn")
const RUN_SCENE = preload("res://scenes/run/run.tscn")
const COMPENDIUM_SCENE := preload("res://scenes/ui/card_compendium_view.tscn")

@export var run_startup: RunStartup

@onready var continue_button: Button = %Continue
@onready var card_keyword_tooltip: CardKeywordTooltip = $TooltipLayer/CardKeywordTooltip

var _compendium: CardCompendiumView


func _ready() -> void:
	add_to_group("main_menu")
	get_tree().paused = false
	continue_button.disabled = SaveGame.load_data() == null
	if not Events.card_keyword_tooltip_show.is_connected(card_keyword_tooltip.show_keyword_blocks):
		Events.card_keyword_tooltip_show.connect(card_keyword_tooltip.show_keyword_blocks)
	if not Events.card_keyword_tooltip_hide.is_connected(card_keyword_tooltip.hide_tooltip):
		Events.card_keyword_tooltip_hide.connect(card_keyword_tooltip.hide_tooltip)


func _on_continue_pressed() -> void:
	run_startup.type = RunStartup.Type.CONTINUED_RUN
	get_tree().change_scene_to_packed(RUN_SCENE)


func _on_new_run_pressed() -> void:
	get_tree().change_scene_to_packed(CHAR_SELECTOR_SCENE)


func _on_card_compendium_pressed() -> void:
	if _compendium == null or not is_instance_valid(_compendium):
		_compendium = COMPENDIUM_SCENE.instantiate() as CardCompendiumView
		$CompendiumLayer.add_child(_compendium)
	_compendium.show()


func _on_exit_pressed() -> void:
	get_tree().quit()
