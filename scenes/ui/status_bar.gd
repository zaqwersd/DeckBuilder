class_name StatusBar
extends VBoxContainer

## 悬停状态说明相对图标的水平侧：玩家 true（右侧），敌人请在场景中设为 false（左侧）
@export var status_tooltips_open_to_right: bool = true

## 血条 + 其下横向状态栏（与血条左缘对齐）
@onready var health: HealthUI = $HealthRow


func _ready() -> void:
	alignment = ALIGNMENT_BEGIN
	var sh := $StatusHandler as StatusHandler
	if sh:
		sh.tooltips_open_to_right = status_tooltips_open_to_right
	for c in get_children():
		if c is Control:
			(c as Control).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN


func update_stats(stats: Stats) -> void:
	health.update_stats(stats)
	health.visible = stats.health > 0
