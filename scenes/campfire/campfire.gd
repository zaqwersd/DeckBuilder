class_name Campfire
extends Control

const DECK_PICKER_OVERLAY := preload("res://scenes/ui/deck_picker_overlay.tscn")
const CARD_UPGRADE_FLOW := preload("res://scenes/ui/card_upgrade_flow.tscn")

@export var char_stats: CharacterStats

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var ui_column: Control = $UILayer/UI
@onready var rest_button: Button = %RestButton
@onready var upgrade_button: Button = %UpgradeButton
@onready var leave_button: Button = %LeaveButton
@onready var hint_label: Label = %HintLabel

const HINT_IDLE := "将鼠标移到按钮上查看说明。"
const HINT_REST := "回复最大生命值的30%。"
const HINT_UPGRADE := "选择一张牌升级。"
const HINT_LEAVE := "点击「离开」返回地图。"

## 写入存档用：区分休息 / 升级进入「待离开」；读档回退后再点「离开」会提交。
var _campfire_leave_after_rest: bool = false
var _pre_rest_health_for_save: int = -1
var _upgrade_save_index: int = -1
var _upgrade_save_card_backup: Card = null


func _ready() -> void:
	if hint_label:
		hint_label.text = HINT_IDLE
	if rest_button:
		rest_button.mouse_entered.connect(_on_rest_hint_entered)
		rest_button.mouse_exited.connect(_on_campfire_hint_exited)
	if upgrade_button:
		upgrade_button.mouse_entered.connect(_on_upgrade_hint_entered)
		upgrade_button.mouse_exited.connect(_on_campfire_hint_exited)


func begin_fresh_campfire_visit(run: Run) -> void:
	if run and run.save_data:
		run.save_data.clear_campfire_pending_staging()
	_campfire_leave_after_rest = false
	_pre_rest_health_for_save = -1
	_upgrade_save_index = -1
	_upgrade_save_card_backup = null
	if animation_player:
		animation_player.play(&"RESET")
	if is_instance_valid(ui_column):
		ui_column.modulate = Color.WHITE
	if rest_button:
		rest_button.show()
		rest_button.disabled = false
	if upgrade_button:
		upgrade_button.show()
	if leave_button:
		leave_button.hide()
	if hint_label:
		hint_label.text = HINT_IDLE


func restore_leave_pending_campfire_ui() -> void:
	if animation_player:
		animation_player.play(&"RESET")
	if is_instance_valid(ui_column):
		ui_column.modulate = Color.WHITE
	if rest_button:
		rest_button.hide()
	if upgrade_button:
		upgrade_button.hide()
	if leave_button:
		leave_button.show()
	if hint_label:
		hint_label.text = HINT_LEAVE


func _on_rest_hint_entered() -> void:
	if hint_label:
		hint_label.text = HINT_REST


func _on_upgrade_hint_entered() -> void:
	if hint_label:
		hint_label.text = HINT_UPGRADE


func _on_campfire_hint_exited() -> void:
	if hint_label and is_instance_valid(leave_button) and leave_button.visible:
		hint_label.text = HINT_LEAVE
	elif hint_label:
		hint_label.text = HINT_IDLE


func _upgrade_modal_layer() -> CanvasLayer:
	var existing := get_node_or_null("UpgradeModalLayer") as CanvasLayer
	if existing != null:
		return existing
	var cl := CanvasLayer.new()
	cl.name = "UpgradeModalLayer"
	## 高于营火 UILayer(2)，否则选牌/升级 ColorRect 会画在 CanvasLayer 下面，看不见也点不到。
	cl.layer = 50
	add_child(cl)
	return cl


func _upgrade_picker_ok(c: Card) -> bool:
	return c.has_any_upgradeable_track()


func _enter_campfire_await_leave_phase() -> void:
	var run := get_tree().get_first_node_in_group("run") as Run
	if run and run.save_data:
		var sg := run.save_data
		sg.campfire_leave_pending = true
		if _campfire_leave_after_rest:
			sg.campfire_pending_kind = SaveGame.CAMPFIRE_PENDING_REST
			sg.campfire_pending_pre_health = _pre_rest_health_for_save
			sg.campfire_committed_health = char_stats.health
			sg.campfire_pending_upgrade_index = -1
			sg.campfire_pending_card_backup = null
			sg.campfire_committed_upgrade_card = null
		else:
			sg.campfire_pending_kind = SaveGame.CAMPFIRE_PENDING_UPGRADE
			sg.campfire_pending_pre_health = -1
			sg.campfire_committed_health = -1
			sg.campfire_pending_upgrade_index = _upgrade_save_index
			sg.campfire_pending_card_backup = (
				_upgrade_save_card_backup.duplicate(true) as Card
				if _upgrade_save_card_backup != null
				else null
			)
			var up_ix := _upgrade_save_index
			if up_ix >= 0 and char_stats.deck != null and up_ix < char_stats.deck.cards.size():
				sg.campfire_committed_upgrade_card = char_stats.deck.cards[up_ix].duplicate(true) as Card
			else:
				sg.campfire_committed_upgrade_card = null
		run._save_run(false)
	if animation_player:
		animation_player.play(&"RESET")
	if is_instance_valid(ui_column):
		ui_column.modulate = Color.WHITE
	if rest_button:
		rest_button.hide()
	if upgrade_button:
		upgrade_button.hide()
	if leave_button:
		leave_button.show()
	if hint_label:
		hint_label.text = HINT_LEAVE


func _on_leave_button_pressed() -> void:
	Events.campfire_exited.emit()


func _on_rest_button_pressed() -> void:
	_campfire_leave_after_rest = true
	_pre_rest_health_for_save = char_stats.health
	rest_button.disabled = true
	char_stats.heal(ceili(char_stats.max_health * 0.3))
	if animation_player:
		animation_player.play(&"fade_out")


func _on_upgrade_button_pressed() -> void:
	if char_stats == null or char_stats.deck == null:
		return
	var layer := _upgrade_modal_layer()
	var overlay := DECK_PICKER_OVERLAY.instantiate() as DeckPickerOverlay
	layer.add_child(overlay)
	overlay.setup(
		char_stats.deck,
		1,
		Callable(),
		"选择要升级的牌。",
		PackedStringArray(),
		Callable(),
		Callable(self, "_upgrade_picker_ok"),
		true,
		true
	)
	var indices: Array = await overlay.pick_confirmed
	if indices.is_empty():
		if is_instance_valid(overlay):
			overlay.queue_free()
		return
	var idx := int(indices[0])
	_campfire_leave_after_rest = false
	_upgrade_save_index = idx
	_upgrade_save_card_backup = char_stats.deck.cards[idx].duplicate(true) as Card
	var flow := CARD_UPGRADE_FLOW.instantiate() as CardUpgradeFlow
	layer.add_child(flow)
	flow.begin(char_stats.deck, idx)
	var did_upgrade := bool(await flow.finished)
	if is_instance_valid(overlay):
		overlay.queue_free()
	if not did_upgrade:
		_upgrade_save_index = -1
		_upgrade_save_card_backup = null
		return
	var run := get_tree().get_first_node_in_group("run") as Run
	if run:
		await run.await_deck_gain_card_visual(char_stats.deck.cards[idx], Vector2.ZERO)
	_enter_campfire_await_leave_phase()


# This is called from the AnimationPlayer
# at the end of 'fade-out'.
func _on_fade_out_finished() -> void:
	_enter_campfire_await_leave_phase()
