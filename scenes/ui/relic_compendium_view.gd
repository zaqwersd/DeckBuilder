class_name RelicCompendiumView
extends Control

const RELIC_UI_SCENE := preload("res://scenes/relic_handler/relic_ui.tscn")
const GRID_COLUMNS := 8

signal returned_to_hub

@onready var _sections: VBoxContainer = %Sections
@onready var _relic_scroll: ScrollContainer = %ScrollContainer
@onready var _back_button: Button = %BackButton

var _pointer_exclusive_registered := false

static var _RARITY_ORDER: Array[Relic.Rarity] = [
	Relic.Rarity.STARTER,
	Relic.Rarity.COMMON,
	Relic.Rarity.UNCOMMON,
	Relic.Rarity.RARE,
	Relic.Rarity.SPECIAL,
	Relic.Rarity.SHOP,
]


func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	visibility_changed.connect(_on_visibility_changed_pointer_exclusive)
	_on_visibility_changed_pointer_exclusive()
	_refresh_compendium()


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


func _relics_for_rarity(rarity: Relic.Rarity) -> Array[Relic]:
	var out: Array[Relic] = []
	for relic: Relic in GameContent.load_all_relic_templates():
		if relic.rarity == rarity:
			out.append(relic)
	out.sort_custom(func(a: Relic, b: Relic) -> bool:
		return String(a.id) < String(b.id)
	)
	return out


func _refresh_compendium() -> void:
	if _relic_scroll:
		_relic_scroll.scroll_vertical = 0
	for n: Node in _sections.get_children():
		n.queue_free()

	for rarity: Relic.Rarity in _RARITY_ORDER:
		var relics := _relics_for_rarity(rarity)
		if relics.is_empty():
			continue
		_sections.add_child(_make_rarity_section(rarity, relics))


func _make_rarity_section(rarity: Relic.Rarity, relics: Array[Relic]) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 16)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title := Label.new()
	title.text = Relic.RARITY_DISPLAY_NAMES.get(rarity, "")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Relic.RARITY_COLORS.get(rarity, Color.WHITE))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	section.add_child(title)

	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(grid)

	for relic: Relic in relics:
		grid.add_child(_make_relic_slot(relic))

	return section


func _make_relic_slot(relic: Relic) -> VBoxContainer:
	var slot := VBoxContainer.new()
	slot.alignment = BoxContainer.ALIGNMENT_CENTER
	slot.add_theme_constant_override("separation", 8)
	slot.custom_minimum_size = Vector2(80, 96)
	slot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var ui := RELIC_UI_SCENE.instantiate() as RelicUI
	ui.relic = relic
	ui.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.add_child(ui)
	var name_lab := Label.new()
	name_lab.text = relic.relic_name
	name_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lab.custom_minimum_size = Vector2(80, 0)
	name_lab.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	name_lab.add_theme_font_size_override("font_size", 14)
	name_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(name_lab)
	return slot


func show_compendium() -> void:
	_refresh_compendium()
	show()
