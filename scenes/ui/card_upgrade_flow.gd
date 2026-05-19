class_name CardUpgradeFlow
extends CardGridListing

## 战斗内模态升级层：高于 DeckPickerOverlay(6)
const BATTLE_MODAL_CANVAS_LAYER := 7

## 升级流程结束状态
enum Result {
	UPGRADED,      ## 成功升级
	CANCELLED,     ## 彻底取消（关闭整个流程）
	BACK_TO_PICK   ## 返回到选牌界面（仅在非预览模式下）
}

## 本次流程结束；参数为 Result 枚举值
signal finished(result: Result)

var _readonly := false
var _deck: CardPile
var _card_index: int = -1
var _card: Card
var _picked_track: String = ""

@onready var _phase1: VBoxContainer = %Phase1
@onready var _phase2: VBoxContainer = %Phase2
@onready var _center1: CenterContainer = %CenterCard1
@onready var _choices: RichTextLabel = %UpgradeChoices
@onready var _center_left: CenterContainer = %CenterLeft
@onready var _center_right: CenterContainer = %CenterRight
@onready var _upgrade_arrow: TextureRect = %Arrow
@onready var _cancel1: Button = %CancelPhase1
@onready var _cancel2: Button = %CancelPhase2
@onready var _confirm: Button = %ConfirmUpgrade
@onready var _pick_title: Label = %PickTitle
@onready var _upgrade_legend_title_panel: Panel = %UpgradeLegendTitlePanel
@onready var _upgrade_legend_body_panel: Panel = %UpgradeLegendBodyPanel
@onready var _upgrade_legend_richtext: RichTextLabel = %UpgradeLegendRichText

var _menu_center: CardMenuUI
var _menu_left: CardMenuUI
var _menu_right: CardMenuUI
## 与 call_deferred 的升级选词条 UI 配套：阶段切换后丢弃过期回调。
var _pick_ui_stamp: int = 0
## 防止重复 push pointer_exclusive
var _pointer_exclusive_pushed := false


func _ready() -> void:
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_cancel1.pressed.connect(_on_cancel_all)
	_cancel2.pressed.connect(_on_back_to_pick)
	_confirm.pressed.connect(_on_confirm_upgrade)
	if _choices:
		_choices.visible = false
		_choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _upgrade_arrow and _upgrade_arrow.texture:
		_upgrade_arrow.custom_minimum_size = Vector2(_upgrade_arrow.texture.get_size()) * 4.0
	_setup_upgrade_legend_panels()


func _setup_upgrade_legend_panels() -> void:
	if _upgrade_legend_title_panel:
		_upgrade_legend_title_panel.add_theme_stylebox_override(
			"panel", CardUpgradeUiColors.style_panel_flat()
		)
	if _upgrade_legend_body_panel:
		_upgrade_legend_body_panel.add_theme_stylebox_override(
			"panel", CardUpgradeUiColors.style_panel_flat()
		)
	if _upgrade_legend_richtext:
		_upgrade_legend_richtext.bbcode_enabled = true
		_upgrade_legend_richtext.text = CardUpgradeUiColors.legend_bbcode()


func begin(deck: CardPile, card_index: int) -> void:
	_readonly = false
	_deck = deck
	_card_index = card_index
	if _deck == null or _card_index < 0 or _card_index >= _deck.cards.size():
		queue_free()
		finished.emit(false)
		return
	_card = _deck.cards[_card_index]
	if not is_node_ready():
		await ready
	_apply_mode_ui()
	if _card.uses_random_upgrade_track_pick():
		var random_track := _card.pick_random_upgrade_track()
		if random_track.is_empty():
			queue_free()
			finished.emit(Result.CANCELLED)
			return
		_show_phase2(random_track)
	else:
		_show_phase1()
	if not _pointer_exclusive_pushed:
		Events.begin_pointer_exclusive_ui(self)
		_pointer_exclusive_pushed = true


## 牌库观看：仅预览升级链，不写回卡组；取消/返回 为「返回」，无确定键；右侧预览可继续点词条看多层强化。
func begin_preview(for_card: Card) -> void:
	_readonly = true
	_deck = null
	_card_index = -1
	if for_card == null:
		queue_free()
		finished.emit(false)
		return
	_card = for_card
	if not is_node_ready():
		await ready
	_apply_mode_ui()
	_show_phase1()
	if not _pointer_exclusive_pushed:
		Events.begin_pointer_exclusive_ui(self)
		_pointer_exclusive_pushed = true


## 无上宝石遗物专用：直接显示满级预览，跳过词条选择阶段
func begin_max_out(deck: CardPile, card_index: int) -> void:
	_readonly = false
	_deck = deck
	_card_index = card_index
	if _deck == null or _card_index < 0 or _card_index >= _deck.cards.size():
		queue_free()
		finished.emit(Result.CANCELLED)
		return
	_card = _deck.cards[_card_index]
	if not is_node_ready():
		await ready
	_apply_mode_ui()
	_show_max_out_preview()
	if not _pointer_exclusive_pushed:
		Events.begin_pointer_exclusive_ui(self)
		_pointer_exclusive_pushed = true


func _apply_mode_ui() -> void:
	if _pick_title:
		_pick_title.text = "点击词条以显示升级。" if _readonly else "点击词条以升级。"
	if _cancel1:
		_cancel1.text = "返回" if _readonly else "取消"
	if _cancel2:
		_cancel2.text = "返回" if _readonly else "取消"
	if _confirm:
		var show := not _readonly
		_confirm.visible = show
		_confirm.mouse_filter = Control.MOUSE_FILTER_STOP if show else Control.MOUSE_FILTER_IGNORE


func _show_phase1() -> void:
	_pick_ui_stamp += 1
	_picked_track = ""
	_phase2.visible = false
	_phase1.visible = true
	for c: Node in _center_left.get_children():
		var lm := c as CardMenuUI
		if lm and lm.visuals:
			_disconnect_menu_upgrade_pick(lm)
		c.queue_free()
	for c: Node in _center_right.get_children():
		var rm := c as CardMenuUI
		if rm and rm.visuals:
			_disconnect_right_desc_meta(rm.visuals.description_label)
			rm.visuals.configure_cost_upgrade_for_flow(Callable())
		c.queue_free()
	_menu_left = null
	_menu_right = null
	for c: Node in _center1.get_children():
		var m := c as CardMenuUI
		if m and m.visuals:
			_disconnect_menu_upgrade_pick(m)
		c.queue_free()
	_menu_center = create_listing_card_menu()
	_center1.add_child(_menu_center)
	_menu_center.card = _card
	_menu_center.use_listing_hover_zoom = false
	_apply_upgrade_pick_or_normal_description(_menu_center, _card)


func _show_phase2(track_id: String) -> void:
	_pick_ui_stamp += 1
	if is_instance_valid(_menu_center) and is_instance_valid(_menu_center.visuals):
		_disconnect_menu_upgrade_pick(_menu_center)
	_picked_track = track_id
	_phase1.visible = false
	_phase2.visible = true
	for c: Node in _center_left.get_children():
		var lm2 := c as CardMenuUI
		if lm2 and lm2.visuals:
			_disconnect_menu_upgrade_pick(lm2)
		c.queue_free()
	for c: Node in _center_right.get_children():
		var rm2 := c as CardMenuUI
		if rm2 and rm2.visuals:
			_disconnect_right_desc_meta(rm2.visuals.description_label)
			rm2.visuals.configure_cost_upgrade_for_flow(Callable())
		c.queue_free()
	_menu_left = create_listing_card_menu()
	_menu_right = create_listing_card_menu()
	_center_left.add_child(_menu_left)
	_center_right.add_child(_menu_right)
	_menu_left.card = _card
	_apply_upgrade_pick_or_normal_description(_menu_left, _card)
	var preview: Card = _card.duplicate(true) as Card
	preview.increment_upgrade_track(track_id)
	_menu_right.card = preview
	_menu_left.use_listing_hover_zoom = false
	_menu_right.use_listing_hover_zoom = false
	if _readonly:
		_setup_right_preview_meta_chain(preview)


## 无上宝石遗物专用：显示满级预览（跳过词条选择）
func _show_max_out_preview() -> void:
	_pick_ui_stamp += 1
	_picked_track = "max_out"  ## 特殊标记表示批量升级模式
	_phase1.visible = false
	_phase2.visible = true
	for c: Node in _center_left.get_children():
		var lm2 := c as CardMenuUI
		if lm2 and lm2.visuals:
			_disconnect_menu_upgrade_pick(lm2)
		c.queue_free()
	for c: Node in _center_right.get_children():
		var rm2 := c as CardMenuUI
		if rm2 and rm2.visuals:
			_disconnect_right_desc_meta(rm2.visuals.description_label)
			rm2.visuals.configure_cost_upgrade_for_flow(Callable())
		c.queue_free()
	_menu_left = create_listing_card_menu()
	_menu_right = create_listing_card_menu()
	_center_left.add_child(_menu_left)
	_center_right.add_child(_menu_right)
	_menu_left.card = _card
	_apply_upgrade_pick_or_normal_description(_menu_left, _card)
	## 生成满级预览卡牌
	var preview: Card = _card.duplicate(true) as Card
	preview.max_out_all_upgrade_tracks()
	_menu_right.card = preview
	_menu_left.use_listing_hover_zoom = false
	_menu_right.use_listing_hover_zoom = false


func _apply_upgrade_pick_or_normal_description(menu: CardMenuUI, for_card: Card) -> void:
	if menu == null or menu.visuals == null:
		return
	menu.visuals.description_label.bbcode_enabled = true
	if for_card.has_any_upgradeable_track():
		## CardMenuUI.set_card 可能在 await ready 后晚一帧才执行 visuals.set_card，后者会清空升级描述；
		## 推迟到 idle 再套升级选词条，避免描述被清掉、RichText 仍为 IGNORE 导致点不动 meta。
		call_deferred("_deferred_apply_upgrade_pick_ui", menu, for_card, _pick_ui_stamp)
	else:
		_disconnect_menu_upgrade_pick(menu)
		menu.visuals.clear_upgrade_pick_description()


func _deferred_apply_upgrade_pick_ui(menu: CardMenuUI, for_card: Card, stamp: int) -> void:
	if stamp != _pick_ui_stamp:
		return
	if not is_instance_valid(menu) or menu.visuals == null or for_card == null:
		return
	if not for_card.has_any_upgradeable_track():
		return
	menu.visuals.set_upgrade_pick_description(for_card.get_upgrade_pick_description_bbcode())
	_connect_desc_meta(menu.visuals.description_label)
	_configure_cost_upgrade_pick_for_menu(menu, for_card)


func _configure_cost_upgrade_pick_for_menu(menu: CardMenuUI, for_card: Card) -> void:
	if menu == null or menu.visuals == null:
		return
	var ch := for_card.get_upgrade_chain("cost")
	if ch.is_empty() or for_card.is_upgrade_track_maxed("cost"):
		menu.visuals.configure_cost_upgrade_for_flow(Callable())
		return
	menu.visuals.configure_cost_upgrade_for_flow(
		Callable(self, "_on_upgrade_pick_meta_clicked").bind("ugp:cost")
	)


func _configure_cost_upgrade_pick_for_menu_right(preview_card: Card) -> void:
	if not is_instance_valid(_menu_right) or _menu_right.visuals == null:
		return
	var ch := preview_card.get_upgrade_chain("cost")
	if ch.is_empty() or preview_card.is_upgrade_track_maxed("cost"):
		_menu_right.visuals.configure_cost_upgrade_for_flow(Callable())
		return
	_menu_right.visuals.configure_cost_upgrade_for_flow(
		Callable(self, "_on_right_preview_meta_clicked").bind("ugp:cost")
	)


func _disconnect_menu_upgrade_pick(menu: CardMenuUI) -> void:
	if menu == null or not is_instance_valid(menu.visuals):
		return
	_disconnect_desc_meta(menu.visuals.description_label)
	menu.visuals.configure_cost_upgrade_for_flow(Callable())


func _setup_right_preview_meta_chain(preview: Card) -> void:
	if not _readonly or not is_instance_valid(_menu_right) or not _menu_right.visuals:
		return
	_menu_right.visuals.description_label.bbcode_enabled = true
	if preview.has_any_upgradeable_track():
		call_deferred("_deferred_right_preview_pick_ui", preview, _pick_ui_stamp)
	else:
		_disconnect_right_desc_meta(_menu_right.visuals.description_label)
		_menu_right.visuals.configure_cost_upgrade_for_flow(Callable())
		_menu_right.visuals.clear_upgrade_pick_description()


func _deferred_right_preview_pick_ui(preview: Card, stamp: int) -> void:
	if stamp != _pick_ui_stamp:
		return
	if not _readonly or not is_instance_valid(_menu_right) or not _menu_right.visuals or preview == null:
		return
	if not preview.has_any_upgradeable_track():
		return
	_menu_right.visuals.set_upgrade_pick_description(preview.get_upgrade_pick_description_bbcode())
	_connect_right_desc_meta(_menu_right.visuals.description_label)
	_configure_cost_upgrade_pick_for_menu_right(preview)


func _connect_desc_meta(rtl: RichTextLabel) -> void:
	if rtl == null:
		return
	if rtl.meta_clicked.is_connected(_on_upgrade_pick_meta_clicked):
		rtl.meta_clicked.disconnect(_on_upgrade_pick_meta_clicked)
	rtl.meta_clicked.connect(_on_upgrade_pick_meta_clicked)


func _disconnect_desc_meta(rtl: RichTextLabel) -> void:
	if rtl == null:
		return
	if rtl.meta_clicked.is_connected(_on_upgrade_pick_meta_clicked):
		rtl.meta_clicked.disconnect(_on_upgrade_pick_meta_clicked)


func _connect_right_desc_meta(rtl: RichTextLabel) -> void:
	if rtl == null:
		return
	if rtl.meta_clicked.is_connected(_on_right_preview_meta_clicked):
		rtl.meta_clicked.disconnect(_on_right_preview_meta_clicked)
	rtl.meta_clicked.connect(_on_right_preview_meta_clicked)


func _disconnect_right_desc_meta(rtl: RichTextLabel) -> void:
	if rtl == null:
		return
	if rtl.meta_clicked.is_connected(_on_right_preview_meta_clicked):
		rtl.meta_clicked.disconnect(_on_right_preview_meta_clicked)


func _on_right_preview_meta_clicked(meta: Variant) -> void:
	if not _readonly or not is_instance_valid(_menu_right) or _menu_right.card == null:
		return
	var s := str(meta)
	const PFX := "ugp:"
	if not s.begins_with(PFX):
		return
	var tid := s.substr(PFX.length())
	var preview: Card = _menu_right.card
	if preview.is_upgrade_track_maxed(tid):
		return
	preview.increment_upgrade_track(tid)
	_menu_right.card = preview
	_setup_right_preview_meta_chain(preview)


func _on_upgrade_pick_meta_clicked(meta: Variant) -> void:
	var s := str(meta)
	const PFX := "ugp:"
	if not s.begins_with(PFX):
		return
	var tid := s.substr(PFX.length())
	if _card.is_upgrade_track_maxed(tid):
		return
	if _phase2.visible and is_instance_valid(_menu_right):
		if tid == _picked_track:
			return
		_picked_track = tid
		var preview: Card = _card.duplicate(true) as Card
		preview.increment_upgrade_track(tid)
		_menu_right.card = preview
		if _readonly:
			_setup_right_preview_meta_chain(preview)
		return
	_show_phase2(tid)


func _on_back_to_pick() -> void:
	if is_instance_valid(_menu_left) and is_instance_valid(_menu_left.visuals):
		_disconnect_menu_upgrade_pick(_menu_left)
	for c: Node in _center_left.get_children():
		c.queue_free()
	for c: Node in _center_right.get_children():
		var rm := c as CardMenuUI
		if rm and rm.visuals:
			_disconnect_right_desc_meta(rm.visuals.description_label)
			rm.visuals.configure_cost_upgrade_for_flow(Callable())
		c.queue_free()
	_menu_left = null
	_menu_right = null
	_show_phase1()


func _on_confirm_upgrade() -> void:
	if _readonly:
		return
	if _picked_track.is_empty():
		return
	
	## 确保升级时创建副本，避免直接修改原始资源（如模板卡牌）
	if _deck != null and _card_index >= 0 and _card_index < _deck.cards.size():
		## 创建升级后的副本
		var upgraded_card: Card = _card.duplicate(true) as Card
		
		## 无上宝石遗物批量升级模式
		if _picked_track == "max_out":
			upgraded_card.max_out_all_upgrade_tracks()
		else:
			upgraded_card.increment_upgrade_track(_picked_track)
		
		## 替换牌组中的原始卡牌
		_deck.cards[_card_index] = upgraded_card
		_card = upgraded_card
	else:
		## 不在牌组中的卡牌（预览模式），直接修改
		if _picked_track == "max_out":
			_card.max_out_all_upgrade_tracks()
		else:
			_card.increment_upgrade_track(_picked_track)
	
	queue_free()
	finished.emit(Result.UPGRADED)


func _on_cancel_all() -> void:
	## 如果在 Phase2（左右预览界面），返回到 Phase1（选牌界面）
	if _phase2.visible:
		_on_back_to_pick()
		return
	
	## 如果在 Phase1，清理资源
	if is_instance_valid(_menu_center) and is_instance_valid(_menu_center.visuals):
		_disconnect_menu_upgrade_pick(_menu_center)
	if is_instance_valid(_menu_left) and is_instance_valid(_menu_left.visuals):
		_disconnect_menu_upgrade_pick(_menu_left)
	if is_instance_valid(_menu_right) and is_instance_valid(_menu_right.visuals):
		_disconnect_right_desc_meta(_menu_right.visuals.description_label)
		_menu_right.visuals.configure_cost_upgrade_for_flow(Callable())
	
	## 非预览模式下，返回到选牌界面；预览模式下，直接关闭
	if _readonly:
		queue_free()
		finished.emit(Result.CANCELLED)
	else:
		queue_free()
		finished.emit(Result.BACK_TO_PICK)


func _exit_tree() -> void:
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
