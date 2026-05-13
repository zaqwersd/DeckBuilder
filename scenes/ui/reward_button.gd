class_name RewardButton
extends Button

@export var reward_icon: Texture : set = set_reward_icon
@export var reward_text: String : set = set_reward_text

@onready var custom_icon: TextureRect = %CustomIcon
@onready var custom_text: Label = %CustomText

## 若为遗物奖励，悬停时显示遗物说明（与 RelicUI 一致）。
var hover_relic: Relic


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered_reward)
	mouse_exited.connect(_on_mouse_exited_reward)


func _on_mouse_entered_reward() -> void:
	if hover_relic:
		Events.relic_tooltip_hover_show.emit(hover_relic, self)


func _on_mouse_exited_reward() -> void:
	Events.relic_tooltip_hover_hide.emit()


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
	if hover_relic:
		Events.relic_tooltip_hover_hide.emit()
	queue_free()
