class_name CardSelectorScreen
extends Control

## 选牌界面 - 用于让用户从手牌中选择要消耗的卡牌

signal selection_confirmed(selected_cards: Array[Card])
signal selection_cancelled

const COMBAT_CARD_MENU_UI_SCENE := preload("res://scenes/ui/combat_card_menu_ui.tscn")

@onready var overlay: ColorRect = %Overlay
@onready var hand_container: HBoxContainer = %HandContainer
@onready var selected_container: HBoxContainer = %SelectedContainer
@onready var confirm_button: Button = %ConfirmButton
@onready var title_label: Label = %TitleLabel

var _available_cards: Array[Card] = []
var _selected_cards: Array[Card] = []
var _required_count: int = 1
var _filter_condition: Callable = Callable()
var _card_ui_map: Dictionary = {}  # Card -> CardMenuUI
var _original_positions: Dictionary = {}  # CardMenuUI -> Vector2

var _pointer_exclusive_registered := false


func _ready() -> void:
	hide()
	confirm_button.pressed.connect(_on_confirm_pressed)
	visibility_changed.connect(_on_visibility_changed_pointer_exclusive)


func _on_visibility_changed_pointer_exclusive() -> void:
	if is_visible_in_tree():
		if not _pointer_exclusive_registered:
			Events.begin_pointer_exclusive_ui(self)
			_pointer_exclusive_registered = true
	else:
		if _pointer_exclusive_registered:
			Events.end_pointer_exclusive_ui(self)
			_pointer_exclusive_registered = false


func show_selector(
	available_cards: Array[Card],
	title: String = "选择要消耗的卡牌",
	required_count: int = 1,
	filter_condition: Callable = Callable()
) -> void:
	_available_cards = available_cards
	_required_count = required_count
	_filter_condition = filter_condition
	_selected_cards.clear()
	_card_ui_map.clear()
	_original_positions.clear()
	
	title_label.text = title
	confirm_button.hide()
	
	_clear_containers()
	_setup_cards()
	
	show()


func _clear_containers() -> void:
	for child in hand_container.get_children():
		child.queue_free()
	for child in selected_container.get_children():
		child.queue_free()


func _setup_cards() -> void:
	for card in _available_cards:
		# 如果有筛选条件，检查是否符合
		if _filter_condition.is_valid() and not _filter_condition.call(card):
			continue
		
		var card_ui := _create_card_ui(card)
		hand_container.add_child(card_ui)
		_card_ui_map[card] = card_ui
		
		# 连接点击事件
		card_ui.gui_input.connect(_on_card_ui_input.bind(card, card_ui))


func _create_card_ui(card: Card) -> CardMenuUI:
	var menu := COMBAT_CARD_MENU_UI_SCENE.instantiate() as CardMenuUI
	menu.use_listing_hover_zoom = true
	menu.mouse_filter = Control.MOUSE_FILTER_STOP
	menu.card = card
	menu.call_deferred("refresh_listing_hover_pivot")
	return menu


func _on_card_ui_input(event: InputEvent, card: Card, card_ui: CardMenuUI) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _selected_cards.has(card):
			_deselect_card(card, card_ui)
		else:
			_select_card(card, card_ui)


func _select_card(card: Card, card_ui: CardMenuUI) -> void:
	if _selected_cards.size() >= _required_count:
		return  # 已达到所需数量
	
	_selected_cards.append(card)
	
	# 保存原始位置
	_original_positions[card_ui] = card_ui.global_position
	
	# 从手牌容器移除，添加到选中容器
	card_ui.get_parent().remove_child(card_ui)
	selected_container.add_child(card_ui)
	
	# 动画飞到中央
	_animate_card_to_center(card_ui, _selected_cards.size() - 1)
	
	# 检查是否达到所需数量
	if _selected_cards.size() >= _required_count:
		_show_confirm_button()


func _deselect_card(card: Card, card_ui: CardMenuUI) -> void:
	_selected_cards.erase(card)
	
	# 从选中容器移除，添加到手牌容器
	card_ui.get_parent().remove_child(card_ui)
	hand_container.add_child(card_ui)
	
	# 动画回到原始位置
	if _original_positions.has(card_ui):
		var target_pos := _original_positions[card_ui]
		_animate_card_return(card_ui, target_pos)
	
	# 重新排列剩余选中的卡牌
	_rearrange_selected_cards()
	
	# 隐藏确认按钮
	confirm_button.hide()


func _animate_card_to_center(card_ui: CardMenuUI, index: int) -> void:
	# 计算位置：水平居中，根据索引偏移
	var viewport_size := get_viewport().get_visible_rect().size
	var center_x := viewport_size.x / 2
	var spacing := 220.0  # 卡牌间距
	var start_x := center_x - ((_selected_cards.size() - 1) * spacing) / 2
	var target_x := start_x + index * spacing
	var target_y := viewport_size.y / 2 - 150  # 屏幕中央偏上
	
	var target_pos := Vector2(target_x, target_y)
	
	# 创建动画
	var tween := create_tween().set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_ui, "global_position", target_pos, 0.3)
	tween.parallel().tween_property(card_ui, "scale", Vector2(1.2, 1.2), 0.3)


func _animate_card_return(card_ui: CardMenuUI, target_pos: Vector2) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_ui, "global_position", target_pos, 0.3)
	tween.parallel().tween_property(card_ui, "scale", Vector2.ONE, 0.3)


func _rearrange_selected_cards() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var center_x := viewport_size.x / 2
	var spacing := 220.0
	var start_x := center_x - ((_selected_cards.size() - 1) * spacing) / 2
	var target_y := viewport_size.y / 2 - 150
	
	for i in range(_selected_cards.size()):
		var card := _selected_cards[i]
		var card_ui := _card_ui_map[card]
		var target_x := start_x + i * spacing
		var target_pos := Vector2(target_x, target_y)
		
		var tween := create_tween().set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
		tween.tween_property(card_ui, "global_position", target_pos, 0.2)


func _show_confirm_button() -> void:
	confirm_button.show()
	confirm_button.modulate.a = 0
	
	var tween := create_tween()
	tween.tween_property(confirm_button, "modulate:a", 1.0, 0.3)
	
	# 按钮位置：在选中卡牌下方
	var viewport_size := get_viewport().get_visible_rect().size
	confirm_button.position = Vector2(
		viewport_size.x / 2 - confirm_button.size.x / 2,
		viewport_size.y / 2 + 50
	)


func _on_confirm_pressed() -> void:
	selection_confirmed.emit(_selected_cards.duplicate())
	hide()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		selection_cancelled.emit()
		hide()


func hide() -> void:
	super.hide()
	selection_cancelled.emit()
