@tool
class_name ShopLayoutSlot
extends Control
## 商店固定区域：在编辑器里拖位置和大小；运行时只替换 Content 里的商品，不改槽位本身。

const CONTENT_NODE_NAME := "Content"


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_clear_editor_placeholders()


func get_content() -> CenterContainer:
	return get_node_or_null(CONTENT_NODE_NAME) as CenterContainer


func mount_item(item: Control) -> void:
	var content := _ensure_content()
	for child: Node in content.get_children():
		child.queue_free()
	content.add_child(item)
	_prepare_mounted_item(item)


func clear_runtime_items() -> void:
	var content := get_content()
	if content == null:
		return
	for child: Node in content.get_children():
		child.queue_free()


func _ensure_content() -> CenterContainer:
	var content := get_content()
	if content != null:
		return content
	content = CenterContainer.new()
	content.name = CONTENT_NODE_NAME
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.clip_contents = false
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.anchor_right = 1.0
	content.anchor_bottom = 1.0
	content.offset_left = 0.0
	content.offset_top = 0.0
	content.offset_right = 0.0
	content.offset_bottom = 0.0
	add_child(content)
	return content


func _prepare_mounted_item(item: Control) -> void:
	item.clip_contents = false
	if item is BoxContainer:
		var box := item as BoxContainer
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	else:
		item.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		item.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _clear_editor_placeholders() -> void:
	var content := get_content()
	if content == null:
		return
	for child: Node in content.get_children():
		if str(child.name).begins_with("EditorPlaceholder"):
			child.queue_free()
