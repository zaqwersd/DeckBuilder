class_name BattleUI
extends CanvasLayer

const GAME_TOOLTIP_SCENE := preload("res://scenes/ui/game_tooltip.tscn")
## 高于手牌抬起与飞牌幽灵，保证战斗词条 tooltip 可见
const COMBAT_KEYWORD_TOOLTIP_Z_INDEX := 600

@export var char_stats: CharacterStats : set = _set_char_stats

## 不用 @onready %Hand：父节点可能在子树就绪前调用 start_battle() 触发 setter，且 % 在部分实例化路径下可能为 null
var hand: Hand
var _combat_keyword_tooltip: GameTooltip = null
@onready var mana_ui: ManaUI = $ManaUI
@onready var end_turn_button: Button = %EndTurnButton
@onready var draw_pile_button: CardPileOpener = %DrawPileButton
@onready var discard_pile_button: CardPileOpener = %DiscardPileButton
@onready var exhaust_pile_button: CardPileOpener = %ExhaustPileButton
@onready var card_fx: Node = $CardFxLayer
@onready var draw_pile_view: CardPileView = %DrawPileView
@onready var discard_pile_view: CardPileView = %DiscardPileView
@onready var exhaust_pile_view: CardPileView = %ExhaustPileView


func _ready() -> void:
	hand = _resolve_hand_node()
	_setup_end_turn_button()
	Events.player_hand_drawn.connect(_on_player_hand_drawn)
	end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	draw_pile_button.pressed.connect(draw_pile_view.show_current_view.bind("抽牌堆", true))
	discard_pile_button.pressed.connect(discard_pile_view.show_current_view.bind("弃牌堆"))
	exhaust_pile_button.pressed.connect(exhaust_pile_view.show_current_view.bind("消耗牌堆"))
	draw_pile_view.visibility_changed.connect(_sync_hand_input_for_open_pile_views)
	discard_pile_view.visibility_changed.connect(_sync_hand_input_for_open_pile_views)
	exhaust_pile_view.visibility_changed.connect(_sync_hand_input_for_open_pile_views)
	if char_stats:
		_apply_char_stats_to_ui_nodes()
	_bind_combat_keyword_tooltip()


func _exit_tree() -> void:
	_unbind_combat_keyword_tooltip()


func _bind_combat_keyword_tooltip() -> void:
	if _combat_keyword_tooltip != null:
		return
	_combat_keyword_tooltip = GAME_TOOLTIP_SCENE.instantiate() as GameTooltip
	_combat_keyword_tooltip.z_index = COMBAT_KEYWORD_TOOLTIP_Z_INDEX
	_combat_keyword_tooltip.z_as_relative = false
	_combat_keyword_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_combat_keyword_tooltip)
	if not Events.card_keyword_tooltip_show.is_connected(_on_combat_keyword_tooltip_show):
		Events.card_keyword_tooltip_show.connect(_on_combat_keyword_tooltip_show)
	if not Events.card_keyword_tooltip_hide.is_connected(_on_combat_keyword_tooltip_hide):
		Events.card_keyword_tooltip_hide.connect(_on_combat_keyword_tooltip_hide)


func _unbind_combat_keyword_tooltip() -> void:
	if _combat_keyword_tooltip == null:
		return
	if Events.card_keyword_tooltip_show.is_connected(_on_combat_keyword_tooltip_show):
		Events.card_keyword_tooltip_show.disconnect(_on_combat_keyword_tooltip_show)
	if Events.card_keyword_tooltip_hide.is_connected(_on_combat_keyword_tooltip_hide):
		Events.card_keyword_tooltip_hide.disconnect(_on_combat_keyword_tooltip_hide)
	_combat_keyword_tooltip.hide_tooltip()
	_combat_keyword_tooltip.queue_free()
	_combat_keyword_tooltip = null


func _on_combat_keyword_tooltip_show(ids: PackedStringArray, near_to: Control) -> void:
	if not CardKeywordBbcode.is_combat_tooltip_anchor(near_to):
		return
	if Events.is_pointer_ui_obscured_for(_combat_keyword_tooltip):
		return
	ids = CardKeywordBbcode.without_color_tooltip_ids(ids)
	if ids.is_empty():
		return
	_combat_keyword_tooltip.show_keyword_blocks(ids, near_to)


func _on_combat_keyword_tooltip_hide() -> void:
	if _combat_keyword_tooltip == null:
		return
	_combat_keyword_tooltip.hide_tooltip()


func _setup_end_turn_button() -> void:
	# 飞牌幽灵 z=400、拖拽卡 z=128，必须更高以免被挡
	end_turn_button.z_index = 500
	end_turn_button.z_as_relative = false
	var p := end_turn_button.get_parent()
	if p:
		p.move_child(end_turn_button, p.get_child_count() - 1)
	end_turn_button.add_theme_stylebox_override("normal", _gray_button_style(0.42))
	end_turn_button.add_theme_stylebox_override("hover", _gray_button_style(0.5))
	end_turn_button.add_theme_stylebox_override("pressed", _gray_button_style(0.34))
	end_turn_button.add_theme_stylebox_override("disabled", _gray_button_style(0.36))
	end_turn_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _gray_button_style(lightness: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(lightness, lightness, lightness, 1.0)
	s.set_border_width_all(4)
	s.border_color = Color(0.55, 0.55, 0.55, 1)
	return s


func initialize_card_pile_ui() -> void:
	draw_pile_button.card_pile = char_stats.draw_pile
	draw_pile_view.card_pile = char_stats.draw_pile
	discard_pile_button.card_pile = char_stats.discard
	discard_pile_view.card_pile = char_stats.discard
	exhaust_pile_button.card_pile = char_stats.exhaust
	exhaust_pile_view.card_pile = char_stats.exhaust
	if card_fx:
		card_fx.setup(draw_pile_button, discard_pile_button, exhaust_pile_button)


func _set_char_stats(value: CharacterStats) -> void:
	char_stats = value
	if not is_node_ready():
		return
	_apply_char_stats_to_ui_nodes()


func _resolve_hand_node() -> Hand:
	var h := get_node_or_null("%Hand") as Hand
	if h == null:
		h = get_node_or_null("HandAnchor/Hand") as Hand
	if h == null:
		h = get_node_or_null("Hand") as Hand
	if h == null:
		push_error("BattleUI: 未找到 Hand（已尝试 %Hand / HandAnchor/Hand / Hand）。")
	return h


func _apply_char_stats_to_ui_nodes() -> void:
	if hand == null or not is_instance_valid(hand):
		hand = _resolve_hand_node()
	if mana_ui and char_stats:
		mana_ui.char_stats = char_stats
	if hand and char_stats:
		hand.char_stats = char_stats


func _on_player_hand_drawn() -> void:
	end_turn_button.disabled = false


## 任一堆视图打开时禁用手牌；关闭后仅在「我方回合」（结束回合按钮可用）时恢复，避免敌回合误开手牌。
func _sync_hand_input_for_open_pile_views() -> void:
	if hand == null or not is_instance_valid(hand):
		hand = _resolve_hand_node()
	if hand == null:
		return
	var any_open := (
		draw_pile_view.visible or discard_pile_view.visible or exhaust_pile_view.visible
	)
	if any_open:
		hand.disable_hand()
	elif not end_turn_button.disabled:
		hand.enable_hand()


func _on_end_turn_button_pressed() -> void:
	end_turn_button.disabled = true
	Events.player_turn_ended.emit()
