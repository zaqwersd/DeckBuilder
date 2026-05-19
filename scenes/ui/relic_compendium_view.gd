class_name RelicCompendiumView
extends Control

const RELIC_UI_SCENE := preload("res://scenes/relic_handler/relic_ui.tscn")

signal returned_to_hub

@onready var _relics: GridContainer = %Relics
@onready var _relic_scroll: ScrollContainer = %ScrollContainer
@onready var _relic_grid_center: CenterContainer = %RelicGridCenter
@onready var _back_button: Button = %BackButton

var _pointer_exclusive_registered := false


func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	visibility_changed.connect(_on_visibility_changed_pointer_exclusive)
	_on_visibility_changed_pointer_exclusive()
	_refresh_relic_grid()


func _on_visibility_changed_pointer_exclusive() -> void:
	if is_visible_in_tree():
		if not _pointer_exclusive_registered:
			Events.begin_pointer_exclusive_ui(self)
			_pointer_exclusive_registered = true
	else:
		if _pointer_exclusive_registered:
			Events.end_pointer_exclusive_ui(self)
			_pointer_exclusive_registered = false
		Events.relic_tooltip_hover_hide.emit()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()


func _on_back_pressed() -> void:
	Events.relic_tooltip_hover_hide.emit()
	hide()
	returned_to_hub.emit()


func _refresh_relic_grid() -> void:
	if _relic_scroll:
		_relic_scroll.scroll_vertical = 0
	for n: Node in _relics.get_children():
		n.queue_free()
	for relic: Relic in GameContent.load_all_relic_templates():
		var slot := VBoxContainer.new()
		slot.add_theme_constant_override("separation", 8)
		slot.custom_minimum_size = Vector2(80, 96)
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var ui := RELIC_UI_SCENE.instantiate() as RelicUI
		ui.relic = relic
		ui.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.add_child(ui)
		var name_lab := Label.new()
		name_lab.text = relic.relic_name
		name_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lab.add_theme_font_size_override("font_size", 14)
		name_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(name_lab)
		_relics.add_child(slot)
	call_deferred("_sync_relic_grid_horizontal_center")


func _sync_relic_grid_horizontal_center() -> void:
	if not is_instance_valid(_relic_grid_center) or not is_instance_valid(_relic_scroll):
		return
	## ScrollContainer 子节点需铺满可视宽度，CenterContainer 才能把网格水平居中。
	_relic_grid_center.custom_minimum_size = Vector2(_relic_scroll.size.x, 0.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_visible_in_tree():
		_sync_relic_grid_horizontal_center()


func show_compendium() -> void:
	_refresh_relic_grid()
	show()
	call_deferred("_sync_relic_grid_horizontal_center")
