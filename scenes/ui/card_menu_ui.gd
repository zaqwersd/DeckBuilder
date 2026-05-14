class_name CardMenuUI
extends CenterContainer

## 用于奖励选牌等：在卡面上点击时发出（不再弹出卡牌 tooltip）
signal card_pick_pressed(card: Card)

## 商店 / 卡牌奖励：悬停时卡面 Visuals 放大（不改根 scale，避免与商店槽位布局冲突）
@export var use_listing_hover_zoom := false
const LISTING_HOVER_SCALE := 1.1

@export var card: Card : set = set_card

@onready var visuals: CardVisualsBase = $Visuals

var _listing_hover_tween: Tween
var _deck_pick_selected := false
## 商店/奖励：用几何判断替代 enter/exit，避免缩放或子区域边界抖动
var _listing_hover_geom_active := false


func _ready() -> void:
	# CenterContainer 默认 PASS 会把点击交给父级，奖励/商店里父级是整屏遮罩时子卡永远点不到
	mouse_filter = Control.MOUSE_FILTER_STOP
	if visuals:
		visuals.mouse_filter = Control.MOUSE_FILTER_STOP
	if use_listing_hover_zoom:
		_disconnect_listing_hover_signals()
		set_process(true)
	else:
		set_process(false)
	call_deferred("refresh_listing_hover_pivot")


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and is_instance_valid(visuals):
		if visuals.freeze_font_sync_for_fly_phantom:
			return
		visuals.schedule_minimum_screen_font_sync()


func _disconnect_listing_hover_signals() -> void:
	if not visuals:
		return
	if visuals.mouse_entered.is_connected(_on_visuals_mouse_entered):
		visuals.mouse_entered.disconnect(_on_visuals_mouse_entered)
	if visuals.mouse_exited.is_connected(_on_visuals_mouse_exited):
		visuals.mouse_exited.disconnect(_on_visuals_mouse_exited)


func _listing_mouse_over_visuals() -> bool:
	if Events.is_pointer_ui_obscured_for(self):
		return false
	if not visuals:
		return false
	## 父级 hide 后 get_global_rect 仍可能落在原屏幕区域，必须用可见性否则「幽灵」悬停与 tooltip
	if not is_visible_in_tree():
		return false
	var gr := visuals.get_global_rect()
	return gr.grow(4.0).has_point(get_global_mouse_position())


## 商店 / 卡牌奖励等列表缩略图：与悬停放大同一几何判定
func is_listing_pointer_over_visuals() -> bool:
	return use_listing_hover_zoom and _listing_mouse_over_visuals()


func _process(_delta: float) -> void:
	if not use_listing_hover_zoom or not visuals:
		return
	if Events.is_pointer_ui_obscured_for(self):
		if _listing_hover_geom_active or not is_equal_approx(visuals.scale.x, 1.0):
			_listing_hover_geom_active = false
			_apply_deck_pick_panel_style()
			_tween_listing_hover_scale(false)
		return
	var want := _listing_mouse_over_visuals()
	if want == _listing_hover_geom_active:
		return
	_listing_hover_geom_active = want
	if want:
		if not _deck_pick_selected:
			visuals.panel.set("theme_override_styles/panel", visuals.main_panel_style_hover)
		_tween_listing_hover_scale(true)
	else:
		_apply_deck_pick_panel_style()
		_tween_listing_hover_scale(false)


func set_modifier_preview(player_modifiers: ModifierHandler, enemy_modifiers: ModifierHandler) -> void:
	if is_node_ready() and visuals:
		visuals.apply_modifier_context(player_modifiers, enemy_modifiers)


func _on_visuals_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_mouse") and card:
		card_pick_pressed.emit(card)


func refresh_listing_hover_pivot() -> void:
	if not visuals:
		return
	var sz := visuals.get_rect().size
	if sz.x < 4.0 or sz.y < 4.0:
		sz = visuals.get_combined_minimum_size()
	if sz.x < 4.0 or sz.y < 4.0:
		return
	visuals.pivot_offset = sz * 0.5


func _on_visuals_mouse_entered() -> void:
	if Events.is_pointer_ui_obscured_for(self):
		return
	if use_listing_hover_zoom:
		return
	if not _deck_pick_selected:
		visuals.panel.set("theme_override_styles/panel", visuals.main_panel_style_hover)
	_tween_listing_hover_scale(true)


func _on_visuals_mouse_exited() -> void:
	if Events.is_pointer_ui_obscured_for(self):
		return
	if use_listing_hover_zoom:
		return
	_apply_deck_pick_panel_style()
	_tween_listing_hover_scale(false)


func set_deck_pick_selected(on: bool) -> void:
	_deck_pick_selected = on
	_apply_deck_pick_panel_style()


func _apply_deck_pick_panel_style() -> void:
	if not visuals:
		return
	if _deck_pick_selected:
		var glow := visuals.main_panel_style_base.duplicate() as StyleBoxFlat
		const bw := 3
		glow.set_border_width_all(bw)
		glow.border_color = Color(0.98, 0.92, 0.42, 1.0)
		visuals.panel.add_theme_stylebox_override("panel", glow)
	else:
		visuals.panel.add_theme_stylebox_override("panel", visuals.main_panel_style_base)


func _tween_listing_hover_scale(hover: bool) -> void:
	if not use_listing_hover_zoom or not visuals:
		return
	if _listing_hover_tween and _listing_hover_tween.is_running():
		_listing_hover_tween.kill()
	var target := Vector2.ONE * LISTING_HOVER_SCALE if hover else Vector2.ONE
	_listing_hover_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_listing_hover_tween.tween_property(visuals, "scale", target, 0.11)


func set_card(value: Card) -> void:
	if not is_node_ready():
		await ready

	card = value
	visuals.card = card
