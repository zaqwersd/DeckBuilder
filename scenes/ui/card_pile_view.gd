class_name CardPileView
extends CardGridListing

const CARD_UPGRADE_FLOW := preload("res://scenes/ui/card_upgrade_flow.tscn")
const COMBAT_CARD_MENU_UI_SCENE := preload("res://scenes/ui/combat_card_menu_ui.tscn")

@export var card_pile: CardPile
## 战斗中略小于 1；跑图牌库界面可保持 1。与 CardMenuUI 设计尺寸配套的中心缩放。
@export_range(0.65, 1.0, 0.01) var display_scale: float = 1.0
## 战斗三牌堆为 COMBAT（白字 + 数值红绿）；跑图牌库等保持默认 LISTING（黄/灰/红词条色）。
@export var number_bbcode_style: Card.NumberBbcodeStyle = Card.NumberBbcodeStyle.LISTING_UPGRADE

@onready var title: Label = %Title
@onready var cards: GridContainer = %Cards
@onready var back_button: Button = %BackButton

var _deck_upgrade_input_blocker: Control
var _pointer_exclusive_registered := false


func get_card_listing_grid() -> GridContainer:
	return cards


func _ready() -> void:
	super._ready()
	back_button.pressed.connect(hide)
	visibility_changed.connect(_on_visibility_changed_pointer_exclusive)
	_on_visibility_changed_pointer_exclusive()

	for card: Node in cards.get_children():
		card.queue_free()


func _on_visibility_changed_pointer_exclusive() -> void:
	if is_visible_in_tree():
		if not _pointer_exclusive_registered:
			Events.begin_pointer_exclusive_ui(self)
			_pointer_exclusive_registered = true
	else:
		if _pointer_exclusive_registered:
			Events.end_pointer_exclusive_ui(self)
			_pointer_exclusive_registered = false


## 覆盖父类方法：根据 number_bbcode_style 创建不同的 CardMenuUI
func create_listing_card_menu() -> CardMenuUI:
	if number_bbcode_style == Card.NumberBbcodeStyle.COMBAT_PILES_AND_HAND:
		# 战斗牌堆：使用 CombatCardVisuals（白底 + 红绿变化）
		var menu := COMBAT_CARD_MENU_UI_SCENE.instantiate() as CardMenuUI
		menu.use_listing_hover_zoom = true
		menu.mouse_filter = Control.MOUSE_FILTER_STOP
		menu.call_deferred("refresh_listing_hover_pivot")
		return menu
	else:
		# 列表模式：使用默认的 ListingCardVisuals（黄/灰/红）
		return super.create_listing_card_menu()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _is_deck_upgrade_input_blocker_active():
			return
		hide()


func show_current_view(new_title: String, randomized: bool = false) -> void:
	for card: Node in cards.get_children():
		card.queue_free()

	title.text = new_title
	_update_view.call_deferred(randomized)


func _update_view(randomized: bool) -> void:
	if not card_pile:
		return

	var all_cards := card_pile.cards.duplicate()
	if randomized:
		all_cards.shuffle()

	for card: Card in all_cards:
		var new_card := create_listing_card_menu()
		cards.add_child(new_card)
		new_card.visuals.number_bbcode_style = number_bbcode_style
		new_card.card = card
		_connect_listing_card_pick(new_card)
		_apply_pile_card_transform(new_card)

	if is_equal_approx(display_scale, 1.0):
		cards.remove_theme_constant_override("v_separation")
	else:
		cards.add_theme_constant_override("v_separation", int(round(36.0 * display_scale)))

	show()


func _connect_listing_card_pick(menu: CardMenuUI) -> void:
	menu.card_pick_pressed.connect(_on_listing_card_pick_pressed.bind(menu))


func _on_listing_card_pick_pressed(menu: Variant, _picked: Variant) -> void:
	## bind 把 menu 插在第1位，信号原参数 card 在第2位
	## 所以：第1个参数是 CardMenuUI，第2个参数是 Card
	var m := menu as CardMenuUI
	var c := _picked as Card
	if m == null:
		## 万一顺序反了，尝试交换
		m = _picked as CardMenuUI
		c = menu as Card
	if m == null:
		return
	_on_deck_card_pick_for_preview(m, c)


func _on_deck_card_pick_for_preview(menu: CardMenuUI, _picked: Card) -> void:
	if menu == null or menu.card == null:
		return
	_run_deck_upgrade_preview(menu.card)


func _run_deck_upgrade_preview(card: Card) -> void:
	var run := get_tree().get_first_node_in_group("run") as Run
	if run == null or run.deck_view != self:
		return
	var layer := run.get_node_or_null("DeckUpgradeModalLayer") as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "DeckUpgradeModalLayer"
		layer.layer = 75
		run.add_child(layer)
	## 不 hide 牌堆：保持可见，仅挡住与牌堆的交互（避免与升级层抢输入）。
	set_deck_upgrade_preview_blocks_pile_input(true)
	## 打开预览前隐藏 tooltip
	Events.card_keyword_tooltip_hide.emit()
	var flow := CARD_UPGRADE_FLOW.instantiate() as CardUpgradeFlow
	layer.add_child(flow)
	flow.begin_preview(card)
	await flow.finished
	set_deck_upgrade_preview_blocks_pile_input(false)
	## 重置 tooltip 状态
	Events.card_keyword_tooltip_render_pending = false
	if is_instance_valid(flow):
		flow.queue_free()


func _ensure_deck_upgrade_input_blocker() -> Control:
	if is_instance_valid(_deck_upgrade_input_blocker):
		return _deck_upgrade_input_blocker
	var b := Control.new()
	b.name = "DeckUpgradeInputBlocker"
	b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.z_index = 2000
	b.z_as_relative = false
	b.visible = false
	add_child(b)
	_deck_upgrade_input_blocker = b
	return _deck_upgrade_input_blocker


func set_deck_upgrade_preview_blocks_pile_input(blocked: bool) -> void:
	var b := _ensure_deck_upgrade_input_blocker()
	b.visible = blocked


func _is_deck_upgrade_input_blocker_active() -> bool:
	return is_instance_valid(_deck_upgrade_input_blocker) and _deck_upgrade_input_blocker.visible


func _apply_pile_card_transform(menu: CardMenuUI) -> void:
	# number_bbcode_style 由创建时的场景选择自动处理
	menu.scale = Vector2.ONE
	menu.pivot_offset = Vector2.ZERO
	if not is_equal_approx(display_scale, 1.0):
		menu.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
