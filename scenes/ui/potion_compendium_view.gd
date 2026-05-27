class_name PotionCompendiumView
extends Control

const SLOT_MIN_WIDTH := 80.0
const SLOT_MIN_HEIGHT := 96.0
const ROW_SEPARATION := 24

signal returned_to_hub

@onready var _sections: VBoxContainer = %Sections
@onready var _scroll: ScrollContainer = %ScrollContainer
@onready var _back_button: Button = %BackButton

var _pointer_exclusive_registered := false
var _compendium_icon_buttons: Array[Control] = []

static var _RARITY_ORDER: Array[Potion.Rarity] = [
	Potion.Rarity.COMMON,
	Potion.Rarity.UNCOMMON,
	Potion.Rarity.RARE,
	Potion.Rarity.SPECIAL,
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
		Events.potion_tooltip_hover_hide.emit()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()


func _on_back_pressed() -> void:
	Events.potion_tooltip_hover_hide.emit()
	hide()
	returned_to_hub.emit()


func _potions_for_rarity(all_templates: Array[Potion], rarity: Potion.Rarity) -> Array[Potion]:
	var out: Array[Potion] = []
	for potion: Potion in all_templates:
		if potion.rarity == rarity:
			out.append(potion)
	out.sort_custom(func(a: Potion, b: Potion) -> bool:
		return String(a.id) < String(b.id)
	)
	return out


func _refresh_compendium() -> void:
	if _scroll:
		_scroll.scroll_vertical = 0
	_compendium_icon_buttons.clear()
	for n: Node in _sections.get_children():
		n.queue_free()
	var all_templates := GameContent.load_all_potion_templates()
	for rarity: Potion.Rarity in _RARITY_ORDER:
		var potions := _potions_for_rarity(all_templates, rarity)
		if potions.is_empty():
			continue
		_sections.add_child(_make_rarity_section(rarity, potions))


func _make_rarity_section(rarity: Potion.Rarity, potions: Array[Potion]) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 16)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = Potion.RARITY_DISPLAY_NAMES.get(rarity, "")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Potion.RARITY_COLORS.get(rarity, Color.WHITE))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	section.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_SEPARATION)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	section.add_child(row)
	for potion: Potion in potions:
		row.add_child(_make_potion_slot(potion))
	return section


func _make_potion_slot(potion: Potion) -> VBoxContainer:
	var slot := VBoxContainer.new()
	slot.alignment = BoxContainer.ALIGNMENT_CENTER
	slot.add_theme_constant_override("separation", 8)
	slot.custom_minimum_size = Vector2(SLOT_MIN_WIDTH, SLOT_MIN_HEIGHT)
	var icon_btn := TextureButton.new()
	icon_btn.custom_minimum_size = Vector2(64, 64)
	icon_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	icon_btn.texture_normal = potion.icon
	icon_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_compendium_icon_buttons.append(icon_btn)
	icon_btn.mouse_entered.connect(func() -> void:
		Events.potion_tooltip_hover_show.emit(potion, icon_btn)
	)
	icon_btn.mouse_exited.connect(_on_compendium_icon_mouse_exited)
	slot.add_child(icon_btn)
	var name_lab := Label.new()
	name_lab.text = potion.potion_name
	name_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lab.custom_minimum_size = Vector2(SLOT_MIN_WIDTH, 0)
	name_lab.add_theme_font_size_override("font_size", 14)
	name_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(name_lab)
	return slot


func _on_compendium_icon_mouse_exited() -> void:
	call_deferred("_deferred_compendium_tooltip_hide")


func _deferred_compendium_tooltip_hide() -> void:
	var viewport := get_viewport()
	if viewport == null:
		Events.potion_tooltip_hover_hide.emit()
		return
	var screen_pos := CombatPointer.screen_mouse(viewport)
	if TooltipHoverUtil.pointer_over_any_controls(screen_pos, _compendium_icon_buttons):
		return
	Events.potion_tooltip_hover_hide.emit()


func show_compendium() -> void:
	_refresh_compendium()
	show()
