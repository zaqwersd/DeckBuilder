class_name RelicCompendiumView
extends Control

const RELIC_UI_SCENE := preload("res://scenes/relic_handler/relic_ui.tscn")
const SLOT_MIN_WIDTH := 80.0
const SLOT_MIN_HEIGHT := 96.0
const GRID_H_SEPARATION := 24
const GRID_V_SEPARATION := 24

signal returned_to_hub

@onready var _sections: VBoxContainer = %Sections
@onready var _relic_scroll: ScrollContainer = %ScrollContainer
@onready var _back_button: Button = %BackButton

var _pointer_exclusive_registered := false
var _last_grid_layout_width := -1.0

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


func _relics_for_rarity(all_templates: Array[Relic], rarity: Relic.Rarity) -> Array[Relic]:
	var out: Array[Relic] = []
	for relic: Relic in all_templates:
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

	_last_grid_layout_width = -1.0
	var all_templates := GameContent.load_all_relic_templates()

	for rarity: Relic.Rarity in _RARITY_ORDER:
		var relics := _relics_for_rarity(all_templates, rarity)
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
	grid.columns = 1
	grid.add_theme_constant_override("h_separation", GRID_H_SEPARATION)
	grid.add_theme_constant_override("v_separation", GRID_V_SEPARATION)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(grid)

	for relic: Relic in relics:
		grid.add_child(_make_relic_slot(relic))

	return section


func _make_relic_slot(relic: Relic) -> VBoxContainer:
	var slot := VBoxContainer.new()
	slot.alignment = BoxContainer.ALIGNMENT_CENTER
	slot.add_theme_constant_override("separation", 8)
	slot.custom_minimum_size = Vector2(SLOT_MIN_WIDTH, SLOT_MIN_HEIGHT)
	var ui := RELIC_UI_SCENE.instantiate() as RelicUI
	ui.relic = relic
	ui.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.add_child(ui)
	var name_lab := Label.new()
	name_lab.text = relic.relic_name
	name_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lab.custom_minimum_size = Vector2(SLOT_MIN_WIDTH, 0)
	name_lab.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	name_lab.add_theme_font_size_override("font_size", 14)
	name_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(name_lab)
	return slot


func _columns_for_width(content_width: float) -> int:
	if content_width <= 0.0:
		return 1
	return maxi(
		1,
		int(floor((content_width + GRID_H_SEPARATION) / (SLOT_MIN_WIDTH + GRID_H_SEPARATION)))
	)


func _apply_grid_columns_from_scroll_width() -> void:
	if _relic_scroll == null or _sections == null:
		return
	var w := _relic_scroll.size.x
	if w <= 0.0 or is_equal_approx(w, _last_grid_layout_width):
		return
	_last_grid_layout_width = w
	var cols := _columns_for_width(w)
	for section: Node in _sections.get_children():
		if not section is VBoxContainer:
			continue
		var box := section as VBoxContainer
		if box.get_child_count() < 2:
			continue
		var grid := box.get_child(1) as GridContainer
		if grid:
			grid.columns = cols


func show_compendium() -> void:
	_refresh_compendium()
	show()
	await get_tree().process_frame
	_apply_grid_columns_from_scroll_width()
