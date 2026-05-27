class_name RewardButton
extends Button

@export var reward_icon: Texture : set = set_reward_icon
@export var reward_text: String : set = set_reward_text

@onready var custom_icon: TextureRect = %CustomIcon
@onready var custom_text: Label = %CustomText

## 若为遗物奖励，悬停时显示遗物说明（与 RelicUI 一致）。
var hover_relic: Relic
var hover_potion: Potion
## 为 false 时点击后不销毁自身（如「添加新卡牌」需先进入选牌层，返回后仍可再点）。
@export var remove_on_press: bool = true

var _tooltip_hover_depth := 0


func _ready() -> void:
	## 子节点须 IGNORE，否则 Margin/Label/图标会吃掉点击，只有露在外面的边能点到 Button
	_set_mouse_filter_ignore_recursive(self)
	_bind_reward_tooltip_hover(self)


func _set_mouse_filter_ignore_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_mouse_filter_ignore_recursive(child)


func _bind_reward_tooltip_hover(target: Control) -> void:
	if not target.mouse_entered.is_connected(_on_mouse_entered_reward):
		target.mouse_entered.connect(_on_mouse_entered_reward)
	if not target.mouse_exited.is_connected(_on_mouse_exited_reward):
		target.mouse_exited.connect(_on_mouse_exited_reward)


func _on_mouse_entered_reward() -> void:
	_tooltip_hover_depth += 1
	if _tooltip_hover_depth != 1:
		return
	if hover_relic:
		Events.relic_tooltip_hover_show.emit(hover_relic, self)
	elif hover_potion:
		Events.potion_tooltip_hover_show.emit(hover_potion, self)


func _on_mouse_exited_reward() -> void:
	_tooltip_hover_depth = maxi(0, _tooltip_hover_depth - 1)
	if _tooltip_hover_depth > 0:
		return
	call_deferred("_deferred_emit_reward_tooltip_hide")


func _deferred_emit_reward_tooltip_hide() -> void:
	if _tooltip_hover_depth > 0:
		return
	var viewport := get_viewport()
	if viewport == null:
		_emit_reward_tooltip_hide()
		return
	var screen_pos := CombatPointer.screen_mouse(viewport)
	var peers := TooltipHoverUtil.collect_sibling_controls(self, RewardButton)
	if TooltipHoverUtil.pointer_over_control_or_peers(screen_pos, self, peers):
		return
	_emit_reward_tooltip_hide()


func _emit_reward_tooltip_hide() -> void:
	if hover_relic:
		Events.relic_tooltip_hover_hide.emit()
	if hover_potion:
		Events.potion_tooltip_hover_hide.emit()


func set_reward_icon(new_icon: Texture) -> void:
	reward_icon = new_icon
	
	if not is_node_ready():
		await ready
	
	custom_icon.texture = reward_icon


func set_reward_text(new_text: String) -> void:
	reward_text = new_text
	
	if not is_node_ready():
		await ready
	
	custom_text.text = reward_text


func _on_pressed() -> void:
	TooltipHoverUtil.hide_immediate(get_tree())
	if remove_on_press:
		queue_free()
