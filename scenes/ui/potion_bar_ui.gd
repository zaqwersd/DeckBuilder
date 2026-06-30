class_name PotionBarUI
extends PanelContainer

const EMPTY_ICON := preload("res://art/potions/empty_potion.png")
const SLOT_SIZE := Vector2(64, 64)
const BAR_HEIGHT := 64.0
const POPUP_SCENE := preload("res://scenes/ui/potion_action_popup.tscn")

@onready var _slots_row: HBoxContainer = %SlotsRow

var _slot_buttons: Array[TextureButton] = []
var _handler: PotionHandler
var _popup: PotionActionPopup
var _open_slot_index := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_collect_existing_slot_buttons()
	_ensure_button_count(PotionHandler.DEFAULT_SLOTS)
	_update_bar_layout()


func _collect_existing_slot_buttons() -> void:
	_slot_buttons.clear()
	if _slots_row == null:
		return
	for child in _slots_row.get_children():
		if child is TextureButton:
			_register_slot_button(child as TextureButton, _slot_buttons.size())


func _register_slot_button(btn: TextureButton, index: int) -> void:
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.custom_minimum_size = SLOT_SIZE
	if not btn.pressed.is_connected(_on_slot_pressed.bind(index)):
		btn.pressed.connect(_on_slot_pressed.bind(index))
	if not btn.mouse_entered.is_connected(_on_slot_hover.bind(index)):
		btn.mouse_entered.connect(_on_slot_hover.bind(index))
	if not btn.mouse_exited.is_connected(_on_slot_hover_end):
		btn.mouse_exited.connect(_on_slot_hover_end)
	if not _slot_buttons.has(btn):
		_slot_buttons.append(btn)


func _ensure_button_count(count: int) -> void:
	if _slots_row == null:
		return
	while _slot_buttons.size() < count:
		var btn := TextureButton.new()
		btn.name = "Slot%d" % _slot_buttons.size()
		_slots_row.add_child(btn)
		_register_slot_button(btn, _slot_buttons.size())
	while _slot_buttons.size() > count:
		var btn: TextureButton = _slot_buttons.pop_back()
		if is_instance_valid(btn):
			btn.queue_free()


func bind_handler(handler: PotionHandler) -> void:
	if _handler != null and _handler.slots_changed.is_connected(_on_handler_slots_changed):
		_handler.slots_changed.disconnect(_on_handler_slots_changed)
	_handler = handler
	if _handler != null:
		if not _handler.slots_changed.is_connected(_on_handler_slots_changed):
			_handler.slots_changed.connect(_on_handler_slots_changed)
	_refresh_slots()


func refresh_from_handler() -> void:
	_refresh_slots()


func _on_handler_slots_changed() -> void:
	_refresh_slots()
	if is_instance_valid(_popup):
		if (
			_open_slot_index < 0
			or _handler == null
			or _open_slot_index >= _handler.slots.size()
			or _handler.slots[_open_slot_index] == null
		):
			call_deferred("_close_popup")
		else:
			_popup.reposition_to_anchor()


func _refresh_slots() -> void:
	var slot_count := PotionHandler.DEFAULT_SLOTS if _handler == null else _handler.slots.size()
	_ensure_button_count(slot_count)
	_update_bar_layout()
	for i in range(_slot_buttons.size()):
		var btn := _slot_buttons[i]
		var potion: Potion = _handler.slots[i] if _handler != null and i < _handler.slots.size() else null
		if potion != null and potion.icon:
			btn.texture_normal = potion.icon
			btn.texture_pressed = potion.icon
			btn.texture_hover = potion.icon
			btn.disabled = false
		else:
			btn.texture_normal = EMPTY_ICON
			btn.texture_pressed = EMPTY_ICON
			btn.texture_hover = EMPTY_ICON
			btn.disabled = false


func _on_slot_pressed(index: int) -> void:
	_cleanup_stale_popups()
	if _handler == null or index < 0 or index >= _handler.slots.size():
		return
	var potion: Potion = _handler.slots[index]
	if potion == null:
		_close_popup()
		return
	if is_instance_valid(_popup) and _open_slot_index == index:
		_close_popup()
		return
	TooltipHoverUtil.hide_immediate(get_tree())
	_close_popup()
	_open_slot_index = index
	_popup = POPUP_SCENE.instantiate() as PotionActionPopup
	_get_popup_host().add_child(_popup)
	_popup.setup(_handler, index, _slot_buttons[index], potion)
	_popup.closed.connect(_on_popup_closed, CONNECT_ONE_SHOT)


func _on_popup_closed() -> void:
	_popup = null
	_open_slot_index = -1


func _close_popup() -> void:
	if not is_instance_valid(_popup):
		_on_popup_closed()
		return
	var popup := _popup
	_popup = null
	_open_slot_index = -1
	if popup.closed.is_connected(_on_popup_closed):
		popup.closed.disconnect(_on_popup_closed)
	popup.closed.emit()
	popup.queue_free()


func _cleanup_stale_popups() -> void:
	var host := _get_popup_host()
	for child: Node in host.get_children():
		if child is PotionActionPopup and child != _popup:
			child.queue_free()


func _get_popup_host() -> Node:
	var run := get_tree().get_first_node_in_group("run")
	return run if run != null else get_tree().root


func _on_slot_hover(index: int) -> void:
	if is_instance_valid(_popup):
		return
	if _handler == null or index < 0 or index >= _handler.slots.size():
		return
	var potion: Potion = _handler.slots[index]
	if potion != null:
		Events.potion_tooltip_hover_show.emit(potion, _slot_buttons[index])


func _on_slot_hover_end() -> void:
	if is_instance_valid(_popup):
		return
	call_deferred("_deferred_slot_hover_hide")


func _deferred_slot_hover_hide() -> void:
	if is_instance_valid(_popup):
		return
	var viewport := get_viewport()
	if viewport == null:
		Events.potion_tooltip_hover_hide.emit()
		return
	var screen_pos := CombatPointer.screen_mouse(viewport)
	if TooltipHoverUtil.pointer_over_any_controls(screen_pos, _slot_buttons):
		return
	Events.potion_tooltip_hover_hide.emit()


func _get_panel_content_margins() -> Vector4:
	var style := get_theme_stylebox(&"panel") as StyleBoxFlat
	if style == null:
		return Vector4(4.0, 0.0, 4.0, 0.0)
	return Vector4(
		style.content_margin_left,
		style.content_margin_top,
		style.content_margin_right,
		style.content_margin_bottom
	)


func _get_slot_height() -> float:
	var margins := _get_panel_content_margins()
	return maxf(1.0, BAR_HEIGHT - margins.y - margins.w)


func _compute_bar_content_width() -> float:
	var slot_count := _slot_buttons.size()
	if slot_count <= 0:
		return 0.0
	var separation := 0.0
	if _slots_row != null:
		separation = float(_slots_row.get_theme_constant(&"separation"))
	var gaps := maxi(0, slot_count - 1)
	return float(slot_count) * SLOT_SIZE.x + float(gaps) * separation


func _update_bar_layout() -> void:
	var margins := _get_panel_content_margins()
	var content_w := _compute_bar_content_width()
	var slot_h := _get_slot_height()
	for btn in _slot_buttons:
		btn.custom_minimum_size = Vector2(SLOT_SIZE.x, slot_h)
	custom_minimum_size = Vector2(
		content_w + margins.x + margins.z,
		BAR_HEIGHT
	)
