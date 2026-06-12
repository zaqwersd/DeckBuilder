class_name CardUpgradeFlow
extends CardGridListing

## 战斗内模态升级层：高于 DeckPickerOverlay(6)
const BATTLE_MODAL_CANVAS_LAYER := 7

## 升级流程结束状态
enum Result {
	UPGRADED,
	CANCELLED,
	BACK_TO_PICK,
}

signal finished(result: Result)

var _readonly := false
var _deck: CardPile
var _card_index: int = -1
var _card: Card

@onready var _phase1: VBoxContainer = %Phase1
@onready var _phase2: VBoxContainer = %Phase2
@onready var _center_left: CenterContainer = %CenterLeft
@onready var _center_right: CenterContainer = %CenterRight
@onready var _upgrade_arrow: TextureRect = %Arrow
@onready var _cancel2: Button = %CancelPhase2
@onready var _confirm: Button = %ConfirmUpgrade
@onready var _pick_title: Label = %PickTitle

var _menu_left: CardMenuUI
var _menu_right: CardMenuUI
var _pointer_exclusive_pushed := false
var _fixed_keyword_tooltips_active := false
var _fixed_keyword_tooltip_token := 0


func _ready() -> void:
	super._ready()
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _phase1:
		_phase1.visible = false
	_cancel2.pressed.connect(_on_cancel)
	_confirm.pressed.connect(_on_confirm_upgrade)
	if _upgrade_arrow and _upgrade_arrow.texture:
		_upgrade_arrow.custom_minimum_size = Vector2(_upgrade_arrow.texture.get_size()) * 4.0


func begin(deck: CardPile, card_index: int) -> void:
	_readonly = false
	_deck = deck
	_card_index = card_index
	if _deck == null or _card_index < 0 or _card_index >= _deck.cards.size():
		queue_free()
		finished.emit(Result.CANCELLED)
		return
	_card = _deck.cards[_card_index]
	if not _card.can_be_upgraded():
		queue_free()
		finished.emit(Result.CANCELLED)
		return
	if not is_node_ready():
		await ready
	_apply_mode_ui()
	_show_compare()
	if not _pointer_exclusive_pushed:
		Events.begin_pointer_exclusive_ui(self)
		_pointer_exclusive_pushed = true


## 牌库/图鉴：只读左右对比，无确认键。
func begin_preview(for_card: Card) -> void:
	_readonly = true
	_deck = null
	_card_index = -1
	if for_card == null:
		queue_free()
		finished.emit(Result.CANCELLED)
		return
	_card = for_card
	if not is_node_ready():
		await ready
	_apply_mode_ui()
	_show_compare()
	if not _pointer_exclusive_pushed:
		Events.begin_pointer_exclusive_ui(self)
		_pointer_exclusive_pushed = true


func _apply_mode_ui() -> void:
	if _pick_title:
		_pick_title.text = "升级预览" if _readonly else "确认升级这张牌？"
	if _cancel2:
		_cancel2.text = "返回" if _readonly else "取消"
	if _confirm:
		var show := not _readonly
		_confirm.visible = show
		_confirm.mouse_filter = Control.MOUSE_FILTER_STOP if show else Control.MOUSE_FILTER_IGNORE


func _show_compare() -> void:
	if _phase1:
		_phase1.visible = false
	_phase2.visible = true
	for c: Node in _center_left.get_children():
		c.queue_free()
	for c: Node in _center_right.get_children():
		c.queue_free()
	_menu_left = create_listing_card_menu()
	_menu_right = create_listing_card_menu()
	_center_left.add_child(_menu_left)
	_center_right.add_child(_menu_right)
	var base := _unupgraded_card_for_compare(_card)
	_menu_left.card = base
	_menu_left.use_listing_hover_zoom = false
	var preview: Card = base.duplicate(true) as Card
	preview.apply_upgrade()
	_menu_right.card = preview
	_menu_right.use_listing_hover_zoom = false
	_refresh_fixed_right_keyword_tooltips.call_deferred()


## 左栏始终展示未升级模板；图鉴「显示升级」等传入的可能是已 apply_upgrade 的副本。
static func _unupgraded_card_for_compare(card: Card) -> Card:
	if card == null:
		return null
	if not card.is_upgraded:
		return card
	var template := GameContent.load_card_template(card.id)
	if template != null:
		return template
	return card.duplicate(true) as Card


func _refresh_fixed_right_keyword_tooltips() -> void:
	_fixed_keyword_tooltip_token += 1
	var token := _fixed_keyword_tooltip_token
	_run_fixed_right_keyword_tooltips(token)


func _run_fixed_right_keyword_tooltips(token: int) -> void:
	var tip := ensure_elevated_keyword_tooltip()
	if tip == null:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if token != _fixed_keyword_tooltip_token or not is_instance_valid(self):
		return
	if _menu_right == null or not is_instance_valid(_menu_right) or not is_instance_valid(_menu_right.visuals):
		return
	var ids := _menu_right.visuals.get_keyword_tooltip_ids()
	if ids.is_empty():
		_fixed_keyword_tooltips_active = false
		tip.hide_tooltip()
		return
	_fixed_keyword_tooltips_active = true
	await tip.show_keyword_blocks(ids, _menu_right)


func _on_elevated_keyword_tooltip_hide() -> void:
	if _fixed_keyword_tooltips_active:
		return
	if _elevated_keyword_tooltip != null:
		_elevated_keyword_tooltip.hide_tooltip()


func _on_confirm_upgrade() -> void:
	if _readonly:
		return
	if _deck != null and _card_index >= 0 and _card_index < _deck.cards.size():
		var upgraded_card: Card = _card.duplicate(true) as Card
		upgraded_card.apply_upgrade()
		_deck.cards[_card_index] = upgraded_card
		_card = upgraded_card
	queue_free()
	finished.emit(Result.UPGRADED)


func _on_cancel() -> void:
	if _readonly:
		queue_free()
		finished.emit(Result.CANCELLED)
	else:
		queue_free()
		finished.emit(Result.BACK_TO_PICK)


func _exit_tree() -> void:
	_fixed_keyword_tooltip_token += 1
	_fixed_keyword_tooltips_active = false
	if _elevated_keyword_tooltip != null:
		_elevated_keyword_tooltip.hide_tooltip()
	if _pointer_exclusive_pushed:
		Events.end_pointer_exclusive_ui(self)
		_pointer_exclusive_pushed = false


static func open_on_tree(tree: SceneTree) -> CardUpgradeFlow:
	var layer := CanvasLayer.new()
	layer.layer = BATTLE_MODAL_CANVAS_LAYER
	tree.root.add_child(layer)
	var scene: PackedScene = preload("res://scenes/ui/card_upgrade_flow.tscn")
	var inst := scene.instantiate() as CardUpgradeFlow
	inst.set_anchors_preset(Control.PRESET_FULL_RECT)
	inst.set_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(inst)
	inst.tree_exiting.connect(
		func() -> void:
			if is_instance_valid(layer):
				layer.queue_free()
	, CONNECT_ONE_SHOT)
	return inst
