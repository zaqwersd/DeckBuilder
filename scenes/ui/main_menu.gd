extends Control

const CHAR_SELECTOR_SCENE := preload("res://scenes/ui/character_selector.tscn")
const RUN_SCENE = preload("res://scenes/run/run.tscn")
const COMPENDIUM_HUB_SCENE := preload("res://scenes/ui/compendium_hub_menu.tscn")
const CARD_COMPENDIUM_SCENE := preload("res://scenes/ui/card_compendium_view.tscn")
const RELIC_COMPENDIUM_SCENE := preload("res://scenes/ui/relic_compendium_view.tscn")

@export var run_startup: RunStartup

@onready var continue_button: Button = %Continue
@onready var game_tooltip: GameTooltip = $TooltipLayer/GameTooltip
@onready var _compendium_layer: CanvasLayer = $CompendiumLayer

var _compendium_hub: CompendiumHubMenu
var _card_compendium: CardCompendiumView
var _relic_compendium: RelicCompendiumView


func _ready() -> void:
	add_to_group("main_menu")
	get_tree().paused = false
	continue_button.disabled = SaveGame.load_data() == null
	if not Events.card_keyword_tooltip_show.is_connected(game_tooltip.show_keyword_blocks):
		Events.card_keyword_tooltip_show.connect(game_tooltip.show_keyword_blocks)
	if not Events.card_keyword_tooltip_hide.is_connected(game_tooltip.hide_tooltip):
		Events.card_keyword_tooltip_hide.connect(game_tooltip.hide_tooltip)
	if not Events.relic_tooltip_hover_show.is_connected(game_tooltip.show_tooltip):
		Events.relic_tooltip_hover_show.connect(game_tooltip.show_tooltip)
	if not Events.relic_tooltip_hover_hide.is_connected(game_tooltip.hide_tooltip):
		Events.relic_tooltip_hover_hide.connect(game_tooltip.hide_tooltip)


func _ensure_compendium_ui() -> void:
	if _compendium_hub == null or not is_instance_valid(_compendium_hub):
		_compendium_hub = COMPENDIUM_HUB_SCENE.instantiate() as CompendiumHubMenu
		_compendium_layer.add_child(_compendium_hub)
		_compendium_hub.card_compendium_requested.connect(_open_card_compendium)
		_compendium_hub.relic_compendium_requested.connect(_open_relic_compendium)
		_compendium_hub.closed.connect(_hide_all_compendium_ui)
	if _card_compendium == null or not is_instance_valid(_card_compendium):
		_card_compendium = CARD_COMPENDIUM_SCENE.instantiate() as CardCompendiumView
		_compendium_layer.add_child(_card_compendium)
		_card_compendium.returned_to_hub.connect(_return_to_compendium_hub)
	if _relic_compendium == null or not is_instance_valid(_relic_compendium):
		_relic_compendium = RELIC_COMPENDIUM_SCENE.instantiate() as RelicCompendiumView
		_compendium_layer.add_child(_relic_compendium)
		_relic_compendium.returned_to_hub.connect(_return_to_compendium_hub)


func _hide_all_compendium_ui() -> void:
	if is_instance_valid(_card_compendium):
		_card_compendium.hide()
	if is_instance_valid(_relic_compendium):
		_relic_compendium.hide()
	if is_instance_valid(_compendium_hub):
		_compendium_hub.hide()


func _return_to_compendium_hub() -> void:
	_hide_all_compendium_ui()
	if is_instance_valid(_compendium_hub):
		_compendium_hub.show()


func _on_continue_pressed() -> void:
	run_startup.type = RunStartup.Type.CONTINUED_RUN
	get_tree().change_scene_to_packed(RUN_SCENE)


func _on_new_run_pressed() -> void:
	get_tree().change_scene_to_packed(CHAR_SELECTOR_SCENE)


func _on_compendium_pressed() -> void:
	_ensure_compendium_ui()
	_hide_all_compendium_ui()
	_compendium_hub.show()


func _open_card_compendium() -> void:
	_ensure_compendium_ui()
	_compendium_hub.hide()
	_relic_compendium.hide()
	_card_compendium.show()


func _open_relic_compendium() -> void:
	_ensure_compendium_ui()
	_compendium_hub.hide()
	_card_compendium.hide()
	_relic_compendium.show_compendium()


func _on_exit_pressed() -> void:
	get_tree().quit()
