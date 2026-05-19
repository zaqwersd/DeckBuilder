class_name CompendiumHubMenu
extends Control

signal card_compendium_requested
signal relic_compendium_requested
signal closed

@onready var _card_button: Button = %CardCompendiumButton
@onready var _relic_button: Button = %RelicCompendiumButton
@onready var _back_button: Button = %BackButton

var _pointer_exclusive_registered := false


func _ready() -> void:
	_card_button.pressed.connect(func() -> void: card_compendium_requested.emit())
	_relic_button.pressed.connect(func() -> void: relic_compendium_requested.emit())
	_back_button.pressed.connect(_close_hub)
	visibility_changed.connect(_on_visibility_changed_pointer_exclusive)
	_on_visibility_changed_pointer_exclusive()


func _on_visibility_changed_pointer_exclusive() -> void:
	if is_visible_in_tree():
		if not _pointer_exclusive_registered:
			Events.begin_pointer_exclusive_ui(self)
			_pointer_exclusive_registered = true
	else:
		if _pointer_exclusive_registered:
			Events.end_pointer_exclusive_ui(self)
			_pointer_exclusive_registered = false


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel"):
		_close_hub()


func _close_hub() -> void:
	hide()
	closed.emit()
