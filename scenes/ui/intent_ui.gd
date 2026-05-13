class_name IntentUI
extends HBoxContainer

const INTENT_SLOT := preload("res://scenes/ui/intent_slot.tscn")

var _intents_for_hover: Array[Intent] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered_intent_area)
	mouse_exited.connect(_on_mouse_exited_intent_area)


func update_intents(intents: Array[Intent]) -> void:
	_intents_for_hover.clear()
	for it in intents:
		if it != null:
			_intents_for_hover.append(it)
	for c in get_children():
		c.queue_free()
	if intents.is_empty():
		Events.intent_tooltip_hover_hide.emit()
		hide()
		return
	for intent: Intent in intents:
		if intent == null:
			continue
		var slot := INTENT_SLOT.instantiate() as IntentSlot
		add_child(slot)
		slot.setup(intent)
	show()
	call_deferred("_refresh_intent_tooltip_if_hovered")


func _refresh_intent_tooltip_if_hovered() -> void:
	if not is_inside_tree() or _intents_for_hover.is_empty():
		return
	if modulate.a < 0.05:
		return
	if get_global_rect().has_point(get_global_mouse_position()):
		_on_mouse_entered_intent_area()


func _on_mouse_entered_intent_area() -> void:
	if _intents_for_hover.is_empty():
		return
	if modulate.a < 0.05:
		return
	var bbcode := Intent.build_intent_hover_bbcode(_intents_for_hover)
	if bbcode.is_empty():
		return
	Events.intent_tooltip_hover_show.emit(bbcode, self, false)


func _on_mouse_exited_intent_area() -> void:
	Events.intent_tooltip_hover_hide.emit()


## 兼容旧调用：单意图
func update_intent(single: Intent) -> void:
	if single:
		update_intents([single])
	else:
		update_intents([])
