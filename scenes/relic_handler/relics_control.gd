class_name RelicsControl
extends Control

const TWEEN_SCROLL_DURATION := 0.2
const ARROW_WIDTH := 64.0
const RELIC_CELL := 64.0
const BAR_HEIGHT := 72.0
const MIN_RELICS_PER_PAGE := 1
const MAX_RELICS_PER_PAGE := 64

@export var left_button: TextureButton
@export var right_button: TextureButton

@onready var relics: HBoxContainer = %Relics

var relics_per_page := 5
var page_width := 384.0

var num_of_relics := 0
var current_page := 1
var max_page := 0
var tween: Tween
var relics_position: float
var _layout_applying := false


func _ready() -> void:
	relics_position = relics.position.x

	left_button.pressed.connect(_on_left_button_pressed)
	right_button.pressed.connect(_on_right_button_pressed)

	for relic_ui: RelicUI in relics.get_children():
		relic_ui.free()

	relics.child_order_changed.connect(_on_relics_child_order_changed)
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	resized.connect(_on_self_resized)
	call_deferred("_apply_viewport_layout")


func _on_viewport_size_changed() -> void:
	_apply_viewport_layout()


func _on_self_resized() -> void:
	_apply_viewport_layout()


func _get_viewport_bar_width() -> float:
	return get_viewport().get_visible_rect().size.x


func _get_target_relics_strip_width() -> float:
	return maxf(RELIC_CELL, _get_viewport_bar_width() - 2.0 * ARROW_WIDTH)


func _calc_relics_per_page(strip_w: float) -> int:
	## 尽可能多放图标，使 n*CELL + (n-1)*sep 恰好铺满 strip_w（sep 由 _calc_separation 分配余量）
	var n := int(floor(strip_w / RELIC_CELL))
	n = clampi(n, MIN_RELICS_PER_PAGE, MAX_RELICS_PER_PAGE)
	while n > MIN_RELICS_PER_PAGE and float(n) * RELIC_CELL > strip_w + 0.5:
		n -= 1
	return n


func _calc_separation(strip_w: float, per_page: int) -> float:
	if per_page <= 1:
		return 0.0
	return maxf(0.0, (strip_w - float(per_page) * RELIC_CELL) / float(per_page - 1))


func _apply_viewport_layout() -> void:
	if _layout_applying or not is_instance_valid(relics):
		return
	_layout_applying = true

	var bar_w := _get_viewport_bar_width()
	var strip_w := _get_target_relics_strip_width()
	relics_per_page = _calc_relics_per_page(strip_w)
	var sep := _calc_separation(strip_w, relics_per_page)

	page_width = strip_w
	custom_minimum_size = Vector2(strip_w, BAR_HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	relics.custom_minimum_size = Vector2(strip_w, BAR_HEIGHT)
	relics.add_theme_constant_override("separation", int(round(sep)))

	var handler := get_parent() as Control
	if handler:
		handler.custom_minimum_size = Vector2(bar_w, BAR_HEIGHT)
	var relic_row := handler.get_parent() as Control if handler else null
	if relic_row:
		relic_row.custom_minimum_size = Vector2(bar_w, BAR_HEIGHT)

	var max_p := maxi(1, ceili(num_of_relics / float(relics_per_page)))
	current_page = clampi(current_page, 1, max_p)
	relics_position = -float(current_page - 1) * page_width
	relics.position.x = relics_position

	update()
	_layout_applying = false


func update() -> void:
	if not is_instance_valid(left_button) or not is_instance_valid(right_button):
		return

	num_of_relics = relics.get_child_count()
	max_page = maxi(1, ceili(num_of_relics / float(relics_per_page)))

	left_button.disabled = current_page <= 1
	right_button.disabled = current_page >= max_page
	left_button.visible = not left_button.disabled
	right_button.visible = not right_button.disabled


func _tween_to(x_position: float) -> void:
	if tween:
		tween.kill()

	tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(relics, "position:x", x_position, TWEEN_SCROLL_DURATION)


func _on_left_button_pressed() -> void:
	if current_page > 1:
		current_page -= 1
		update()
		relics_position += page_width
		_tween_to(relics_position)


func _on_right_button_pressed() -> void:
	if current_page < max_page:
		current_page += 1
		update()
		relics_position -= page_width
		_tween_to(relics_position)


func _on_relics_child_order_changed() -> void:
	update()
	call_deferred("_apply_viewport_layout")
