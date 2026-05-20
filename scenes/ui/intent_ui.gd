class_name IntentUI
extends HBoxContainer

const INTENT_SLOT := preload("res://scenes/ui/intent_slot.tscn")
const ACTION_START_POP_DURATION := 0.2
const ACTION_START_POP_SCALE_END := 1.2


## 将意图悬停 tooltip 接到 Run 顶栏（战斗内调用一次即可）。
static func ensure_intent_tooltip_handlers_connected(tree: SceneTree) -> void:
	if tree == null:
		return
	var run_node := tree.get_first_node_in_group("run")
	if run_node == null or not (run_node is Run):
		return
	var tip := (run_node as Run).game_tooltip
	if not is_instance_valid(tip):
		return
	if not Events.intent_tooltip_hover_show.is_connected(tip.show_custom_bbcode):
		Events.intent_tooltip_hover_show.connect(tip.show_custom_bbcode)
	if not Events.intent_tooltip_hover_hide.is_connected(tip.hide_tooltip):
		Events.intent_tooltip_hover_hide.connect(tip.hide_tooltip)


func _ready() -> void:
	## 整条意图条对鼠标透明，由 Enemy 统一用全局指针检测（避免被 BattleUI 挡住）。
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func update_intents(intents: Array[Intent]) -> void:
	for c in get_children():
		c.queue_free()
	if intents.is_empty():
		hide()
		return
	for intent: Intent in intents:
		if intent == null:
			continue
		var slot := INTENT_SLOT.instantiate() as IntentSlot
		add_child(slot)
		slot.setup(intent)
	show()


## 兼容旧调用：单意图
func update_intent(single: Intent) -> void:
	if single:
		update_intents([single])
	else:
		update_intents([])


## 敌人开始行动时：意图图标 1→1.2 倍放大并淡出（0.2s）。
func play_action_start_animation() -> void:
	if not is_instance_valid(self) or get_child_count() == 0:
		return

	var slots: Array[Control] = []
	for child in get_children():
		if child is Control:
			slots.append(child as Control)
	if slots.is_empty():
		return

	var tw := create_tween()
	tw.set_parallel(true)
	for slot in slots:
		slot.scale = Vector2.ONE
		slot.modulate = Color.WHITE
		_apply_slot_pivot_center(slot)
		tw.tween_property(
			slot, "scale", Vector2.ONE * ACTION_START_POP_SCALE_END, ACTION_START_POP_DURATION
		)
		tw.tween_property(slot, "modulate:a", 0.0, ACTION_START_POP_DURATION)
	await tw.finished
	hide()


func _apply_slot_pivot_center(slot: Control) -> void:
	var sz := slot.size
	if sz.x < 4.0 or sz.y < 4.0:
		sz = slot.get_combined_minimum_size()
	if sz.x < 4.0:
		sz = Vector2(48.0, 48.0)
	slot.pivot_offset = sz * 0.5
