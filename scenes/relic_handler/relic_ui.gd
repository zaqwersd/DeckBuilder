class_name RelicUI
extends Control

signal relic_pressed(relic: Relic)

@export var relic: Relic : set = set_relic

@onready var icon: TextureRect = $Icon
@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered_relic)
	mouse_exited.connect(_on_mouse_exited_relic)


func set_relic(new_relic: Relic) -> void:
	if not is_node_ready():
		await ready

	relic = new_relic
	icon.texture = relic.icon


func flash() -> void:
	animation_player.play("flash")


func _on_mouse_entered_relic() -> void:
	if relic:
		Events.relic_tooltip_hover_show.emit(relic, self)


func _on_mouse_exited_relic() -> void:
	Events.relic_tooltip_hover_hide.emit()


func _on_gui_input(event: InputEvent) -> void:
	if not event.is_action_pressed("left_mouse"):
		return
	relic_pressed.emit(relic)
