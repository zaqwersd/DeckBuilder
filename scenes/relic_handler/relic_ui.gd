class_name RelicUI
extends Control

signal relic_pressed(relic: Relic)

@export var relic: Relic : set = set_relic

@onready var icon: TextureRect = $Icon
@onready var subscript_label: Label = $Subscript
@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered_relic)
	mouse_exited.connect(_on_mouse_exited_relic)


func set_relic(new_relic: Relic) -> void:
	if not is_node_ready():
		await ready

	relic = new_relic
	icon.texture = RelicIconUtil.get_colored_icon(relic.icon as Texture2D, relic.rarity)
	relic.sync_relic_ui_visual(self)
	set_counter_subscript(-1)


## value < 0 时隐藏；否则在图标右下角显示下标计数（如木剑已打出技能牌数）。
func set_counter_subscript(value: int) -> void:
	if not is_node_ready():
		await ready
	if value < 0:
		subscript_label.visible = false
		return
	subscript_label.visible = true
	subscript_label.text = str(value)


func flash() -> void:
	animation_player.play("flash")


func _on_mouse_entered_relic() -> void:
	if relic:
		Events.relic_tooltip_hover_show.emit(relic, self)


func _on_mouse_exited_relic() -> void:
	Events.relic_tooltip_hover_hide.emit()


func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("right_mouse"):
		if relic != null and relic.try_handle_relic_ui_right_click(self):
			accept_event()
		return
	if not event.is_action_pressed("left_mouse"):
		return
	relic_pressed.emit(relic)
