class_name Hand
extends HBoxContainer

const CARD_UI_SCENE := preload("res://scenes/card_ui/card_ui.tscn")
## 与 `card_ui.tscn` 中 CardUI 的 `custom_minimum_size` 一致
const CARD_UI_BASE_SIZE := Vector2(210, 310)

@export var player: Player
@export var char_stats: CharacterStats

## 在脚本中修改；非 @export，避免战斗场景把检查器值写进 .tscn 后永远覆盖这里。
## 注意：不要用子 Control 的 `scale` 做手牌缩放——`HBoxContainer` 排序时会调用
## `Container.fit_child_in_rect()`，其中固定执行 `set_scale(Vector2.ONE)`，只有靠后的
## 一帧里 deferred 回调可能让你误以为「只有一张牌吃到了 scale」。
var display_scale: float = 0.7
var card_separation: int = 2


func _enter_tree() -> void:
	_apply_card_separation()


func _ready() -> void:
	child_entered_tree.connect(_on_child_entered_tree)
	_apply_card_separation()
	_refresh_hand_card_scales()


func _on_child_entered_tree(node: Node) -> void:
	if node is CardUI:
		call_deferred("_apply_hand_card_transform", node as CardUI)


func _apply_card_separation() -> void:
	if not is_inside_tree():
		return
	add_theme_constant_override("separation", card_separation)
	queue_redraw()
	update_minimum_size()


func _refresh_hand_card_scales() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		if c is CardUI:
			_apply_hand_card_transform(c as CardUI)


func add_card(card: Card) -> void:
	var owning_player := player
	if not is_instance_valid(owning_player):
		# 战斗场景里 Hand 的 @export「玩家」未连上时为 null；默认与 Battle 里布局一致
		owning_player = get_node_or_null("../../Player") as Player
	if not is_instance_valid(owning_player):
		push_error("Hand.add_card: 未设置 player，且无法从 ../../Player 解析到 Player 节点。")
		return

	var new_card_ui := CARD_UI_SCENE.instantiate() as CardUI
	add_child(new_card_ui)
	new_card_ui.reparent_requested.connect(_on_card_ui_reparent_requested)
	new_card_ui.card = card
	new_card_ui.parent = self
	new_card_ui.char_stats = char_stats
	new_card_ui.player_modifiers = owning_player.modifier_handler
	new_card_ui.refresh_combat_description()
	_apply_hand_card_transform(new_card_ui)
	call_deferred("_apply_hand_card_transform", new_card_ui)


func discard_card(card: CardUI) -> void:
	card.queue_free()


func enable_hand() -> void:
	for card: CardUI in get_children():
		card.disabled = false
		card.z_index = 0
		card.refresh_combat_description()
		if card.is_hovered():
			card.card_state_machine.on_mouse_entered()


func disable_hand() -> void:
	for card: CardUI in get_children():
		card.disabled = true
		card.z_index = 0


func _on_card_ui_reparent_requested(child: CardUI) -> void:
	child.disabled = true
	child.reparent(self)
	var new_index := clampi(child.original_index, 0, get_child_count())
	move_child.call_deferred(child, new_index)
	child.set_deferred("disabled", false)
	child.refresh_combat_description()
	_apply_hand_card_transform(child)
	call_deferred("_apply_hand_card_transform", child)


func _apply_hand_card_transform(card_ui: CardUI) -> void:
	if not is_instance_valid(card_ui):
		return
	var s := display_scale
	# 必须保持为 1，否则每次 HBox 排序都会被 Container 盖回 (1,1)
	card_ui.scale = Vector2.ONE

	var scaled_size := Vector2(
		roundf(CARD_UI_BASE_SIZE.x * s),
		roundf(CARD_UI_BASE_SIZE.y * s)
	)

	if is_equal_approx(s, 1.0):
		card_ui.custom_minimum_size = CARD_UI_BASE_SIZE
		card_ui.pivot_offset = Vector2.ZERO
		card_ui.texture_filter = CanvasItem.TEXTURE_FILTER_PARENT_NODE
	else:
		card_ui.custom_minimum_size = scaled_size
		card_ui.pivot_offset = scaled_size * 0.5
		card_ui.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_sync_drop_point_collision(card_ui, scaled_size if not is_equal_approx(s, 1.0) else CARD_UI_BASE_SIZE)


func _sync_drop_point_collision(card_ui: CardUI, hit_size: Vector2) -> void:
	var shape_node := card_ui.get_node_or_null("DropPointDetector/CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	var rect_shape: RectangleShape2D
	if shape_node.shape is RectangleShape2D:
		rect_shape = shape_node.shape as RectangleShape2D
	else:
		rect_shape = RectangleShape2D.new()
		shape_node.shape = rect_shape
	rect_shape.size = hit_size
	shape_node.position = hit_size * 0.5
