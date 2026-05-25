class_name RelicsControl
extends Control

const TWEEN_SCROLL_DURATION := 0.2
const ARROW_WIDTH := 64.0
const RELIC_CELL := 64.0
const RELIC_SEPARATION := 0
const BAR_HEIGHT := 72.0
## 单页总容量（含箭头占用的 1 格）
const PAGE_CAPACITY := 18
const FIRST_PAGE_RELIC_COUNT := 17
const MIDDLE_PAGE_RELIC_COUNT := 16
const LAST_PAGE_MAX_RELIC_COUNT := 17

@export var left_button: TextureButton
@export var right_button: TextureButton

@onready var relics: HBoxContainer = %Relics

var num_of_relics := 0
var current_page := 1
var max_page := 1
var tween: Tween
var relics_position: float
var _layout_applying := false
var _pages: Array[Dictionary] = []


func _ready() -> void:
	relics_position = relics.position.x
	relics.alignment = BoxContainer.ALIGNMENT_BEGIN

	left_button.pressed.connect(_on_left_button_pressed)
	right_button.pressed.connect(_on_right_button_pressed)

	for relic_ui: RelicUI in relics.get_children():
		relic_ui.free()

	relics.child_order_changed.connect(_on_relics_child_order_changed)
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_on_viewport_size_changed):
		vp.size_changed.connect(_on_viewport_size_changed)
	resized.connect(_on_self_resized)
	call_deferred("_refresh_layout")


func _on_viewport_size_changed() -> void:
	_refresh_layout()


func _on_self_resized() -> void:
	_refresh_layout()


func _get_viewport_bar_width() -> float:
	var vp := get_viewport()
	if vp == null:
		return 1280.0
	return vp.get_visible_rect().size.x


static func build_pages(total: int) -> Array[Dictionary]:
	if total <= 0:
		return [{"start": 0, "count": 0, "show_left": false, "show_right": false}]
	if total <= PAGE_CAPACITY:
		return [{"start": 0, "count": total, "show_left": false, "show_right": false}]

	var pages: Array[Dictionary] = []
	var index := 0
	pages.append({
		"start": 0,
		"count": FIRST_PAGE_RELIC_COUNT,
		"show_left": false,
		"show_right": true,
	})
	index = FIRST_PAGE_RELIC_COUNT

	while index < total:
		var remaining := total - index
		if remaining <= LAST_PAGE_MAX_RELIC_COUNT:
			pages.append({
				"start": index,
				"count": remaining,
				"show_left": true,
				"show_right": false,
			})
			break
		pages.append({
			"start": index,
			"count": MIDDLE_PAGE_RELIC_COUNT,
			"show_left": true,
			"show_right": true,
		})
		index += MIDDLE_PAGE_RELIC_COUNT

	return pages


func _get_current_page_info() -> Dictionary:
	if _pages.is_empty():
		return {"start": 0, "count": 0, "show_left": false, "show_right": false}
	return _pages[clampi(current_page - 1, 0, _pages.size() - 1)]


func _relics_run_width(relic_count: int) -> float:
	if relic_count <= 0:
		return 0.0
	return float(relic_count) * RELIC_CELL + float(maxi(0, relic_count - 1)) * float(RELIC_SEPARATION)


func _cumulative_scroll_x(page_index: int) -> float:
	var offset := 0.0
	for i in range(page_index):
		offset += _relics_run_width(_pages[i]["count"])
	return offset


func _refresh_layout() -> void:
	if _layout_applying or not is_instance_valid(relics) or not is_inside_tree():
		return
	_layout_applying = true

	num_of_relics = relics.get_child_count()
	_pages = build_pages(num_of_relics)
	max_page = maxi(1, _pages.size())
	current_page = clampi(current_page, 1, max_page)

	var page := _get_current_page_info()
	var bar_w := _get_viewport_bar_width()
	var arrow_slots := 0
	if page["show_left"]:
		arrow_slots += 1
	if page["show_right"]:
		arrow_slots += 1
	var strip_w := bar_w - float(arrow_slots) * ARROW_WIDTH

	relics.add_theme_constant_override("separation", RELIC_SEPARATION)
	custom_minimum_size = Vector2(strip_w, BAR_HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	relics.custom_minimum_size = Vector2(_relics_run_width(num_of_relics), BAR_HEIGHT)

	var handler := get_parent() as Control
	if handler:
		handler.custom_minimum_size = Vector2(bar_w, BAR_HEIGHT)
	var relic_row := handler.get_parent() as Control if handler else null
	if relic_row:
		relic_row.custom_minimum_size = Vector2(bar_w, BAR_HEIGHT)

	relics_position = -_cumulative_scroll_x(current_page - 1)
	relics.position.x = relics_position

	_update_arrow_buttons(page)
	_layout_applying = false


func update() -> void:
	if not is_instance_valid(left_button) or not is_instance_valid(right_button):
		return
	_refresh_layout()


func _update_arrow_buttons(page: Dictionary) -> void:
	var show_left: bool = page["show_left"]
	var show_right: bool = page["show_right"]
	left_button.visible = show_left
	right_button.visible = show_right
	left_button.disabled = not show_left
	right_button.disabled = not show_right


func _tween_to(x_position: float) -> void:
	if tween:
		tween.kill()
	tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(relics, "position:x", x_position, TWEEN_SCROLL_DURATION)


func _on_left_button_pressed() -> void:
	if current_page <= 1:
		return
	current_page -= 1
	_refresh_layout()
	_tween_to(relics_position)


func _on_right_button_pressed() -> void:
	if current_page >= max_page:
		return
	current_page += 1
	_refresh_layout()
	_tween_to(relics_position)


func _on_relics_child_order_changed() -> void:
	var new_count := relics.get_child_count()
	if new_count != num_of_relics:
		current_page = clampi(current_page, 1, maxi(1, build_pages(new_count).size()))
	update()
