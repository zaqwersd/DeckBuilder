class_name Tooltip
extends PanelContainer

## 战斗内卡牌悬浮提示已移除；此类保留为空壳，避免旧场景引用时报错。

@export var fade_seconds := 0.2

@onready var tooltip_icon: TextureRect = %TooltipIcon
@onready var tooltip_text_label: RichTextLabel = %TooltipText

var tween: Tween


func _ready() -> void:
	modulate = Color.TRANSPARENT
	hide()
