extends Node

const CLICK_SFX := preload("res://art/click.ogg")
const WIRED_META := &"ui_click_sfx_wired"
const SKIP_META := &"no_ui_click_sfx"


func _ready() -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.node_added.connect(_on_node_added)
	call_deferred("_wire_existing", tree.root)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_wire_button(node as BaseButton)


func _wire_existing(node: Node) -> void:
	if node == null:
		return
	if node is BaseButton:
		_wire_button(node as BaseButton)
	for child in node.get_children():
		_wire_existing(child)


func _wire_button(button: BaseButton) -> void:
	if button.has_meta(WIRED_META):
		return
	if button.has_meta(SKIP_META):
		return
	button.set_meta(WIRED_META, true)
	button.mouse_entered.connect(_on_button_mouse_entered.bind(button))
	button.pressed.connect(_on_button_pressed.bind(button))


func _should_play(button: BaseButton) -> bool:
	if button.disabled:
		return false
	if button.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return false
	if not button.is_visible_in_tree():
		return false
	return true


func _on_button_mouse_entered(button: BaseButton) -> void:
	if not _should_play(button):
		return
	SFXPlayer.play(CLICK_SFX)


func _on_button_pressed(button: BaseButton) -> void:
	if not _should_play(button):
		return
	SFXPlayer.play(CLICK_SFX)
