class_name IntentUI
extends HBoxContainer

const INTENT_SLOT := preload("res://scenes/ui/intent_slot.tscn")


## 将意图悬停 tooltip 接到 Run 顶栏（战斗内调用一次即可）。
static func ensure_intent_tooltip_handlers_connected(tree: SceneTree) -> void:
	if tree == null:
		return
	var run_node := tree.get_first_node_in_group("run")
	if run_node == null or not (run_node is Run):
		return
	var tip := (run_node as Run).status_hover_tooltip
	if not is_instance_valid(tip):
		return
	if not Events.intent_tooltip_hover_show.is_connected(tip.show_custom_bbcode):
		Events.intent_tooltip_hover_show.connect(tip.show_custom_bbcode)
	if not Events.intent_tooltip_hover_hide.is_connected(tip.hide):
		Events.intent_tooltip_hover_hide.connect(tip.hide)


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
