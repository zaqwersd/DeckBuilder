extends Node

const HOVER_SFX := preload("res://art/hover.ogg")
const CLICK_SFX := preload("res://art/click.ogg")
const WIRED_META := &"ui_click_sfx_wired"
const SKIP_META := &"no_ui_click_sfx"


func _ready() -> void:
	var tree := get_tree()
	if tree == null:
		return
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)
	if not tree.scene_changed.is_connected(_on_scene_changed):
		tree.scene_changed.connect(_on_scene_changed)
	call_deferred("_wire_tree", tree.root)


func _on_scene_changed() -> void:
	var tree := get_tree()
	if tree == null:
		return
	call_deferred("_wire_tree", tree.root)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_wire_button(node)


func _wire_tree(root: Node) -> void:
	if root == null:
		return
	_wire_existing(root)


func _wire_existing(node: Node) -> void:
	if node == null:
		return
	if node is BaseButton:
		_wire_button(node)
	for child in node.get_children():
		_wire_existing(child)


func _wire_button(node: Node) -> void:
	if not is_instance_valid(node) or not node is BaseButton:
		return
	var button := node as BaseButton
	if button.has_meta(WIRED_META) or button.has_meta(SKIP_META):
		return
	button.set_meta(WIRED_META, true)
	button.mouse_entered.connect(_on_button_mouse_entered.bind(button))
	## 用 button_down：在 pressed 之前触发，避免场景里先 change_scene / queue_free 导致音效回调排不上
	button.button_down.connect(_on_button_click.bind(button))


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
	SFXPlayer.play_ui_hover(HOVER_SFX)


func _on_button_click(button: BaseButton) -> void:
	if not _should_play(button):
		return
	SFXPlayer.play_ui_click(CLICK_SFX)
