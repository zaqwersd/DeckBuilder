@tool
class_name Enemy
extends Area2D

const ARROW_OFFSET := 5
## 与 `enemy.tscn` 中 IntentUI 实例的默认边距一致（供 `Stats.intent_ui_offset` 叠加）。
const _INTENT_UI_BASE_LEFT := -120.0
const _INTENT_UI_BASE_RIGHT := 120.0
const _INTENT_UI_BASE_TOP := -108.0
const _INTENT_UI_BASE_BOTTOM := -45.0
const WHITE_SPRITE_MATERIAL := preload("res://art/white_sprite_material.tres")
const HEAL_FLOAT_COLOR := Color(0.35, 1.0, 0.5, 1.0)
## 瞄准盒按「非透明像素」收缩；低于此 alpha 视为透明。
const HITBOX_ALPHA_THRESHOLD := 0.08
const HITBOX_PAD_PX := 4.0
const INTERACTION_FADE_SEC := 0.2
## 场景布局敌人：StatusBar 绘制在 Visual / Sprite 外观之上。
const SCENE_LAYOUT_STATUS_BAR_Z := 10
## key -> `Rect2i`（贴图像素坐标下的不透明 AABB，size 至少为 1×1）
static var _opaque_texel_aabb_cache: Dictionary = {}

@export var stats: EnemyStats : set = set_enemy_stats

@export_group("编辑器 UI 预览")
## 在 `*_enemy.tscn` 中指定示例行动（AI 子节点名）；留空则取 AI 第一个行动。不写入 .tres。
@export var editor_preview_action: StringName = &"" : set = set_editor_preview_action

@onready var sprite_2d: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var arrow: Sprite2D = $Arrow
@onready var target_highlight: EnemyTargetHighlight = $TargetHighlight
@onready var stats_ui: StatusBar = $StatusBar
@onready var hover_name_overlay: CombatantHoverName = $HoverNameOverlay as CombatantHoverName
@onready var intent_ui: IntentUI = $IntentUI
@onready var status_handler: StatusHandler = $StatusBar/StatusHandler
@onready var modifier_handler: ModifierHandler = $ModifierHandler

var enemy_action_picker: EnemyActionPicker

var current_action: EnemyAction : set = set_current_action

## 由本节点统一驱动意图 tooltip（悬停碰撞体或意图条矩形均可）。
var _intent_hover_tooltip_active: bool = false

var _art_frame_index: int = 0
var _skelton_art_sequence: PackedInt32Array = PackedInt32Array()
var _skelton_art_seq_step: int = 0
var _skelton_last_was_long_seq: bool = false
var _art_anim_timer: Timer
var _awaiting_interrupt_action: bool = false
var _skip_intent_on_action_assign := false
## 本回合已行动：禁止 `update_intent` 再次显示（多敌人刷新、力量同步等）。
var _intent_suppressed := false
## 多帧动画敌人：用全部帧不透明区域并集，避免逐帧收缩导致瞄准盒跳动。
var _fixed_sprite_hitbox_local: Rect2 = Rect2()
var _hitbox_locked := false
## 场景布局敌人：血条/意图位置以 `*_enemy.tscn` 为准，运行时不再重排。
## 攻击牌窗口内 take_damage 计数，用于 player_dealt_attack_damage_to_enemy 信号。
var _pending_player_attack_card_hits: int = 0
var _death_sequence_started := false
var _battle_home_position: Vector2 = Vector2.ZERO
var _battle_home_global_position: Vector2 = Vector2.ZERO
var _battle_home_captured := false
var _pointer_hover := false
var _card_targeting_active := false
var _card_targeting_valid := false
var _interaction_fade_tween: Tween
var _editor_stats_listener: EnemyStats


func _ready() -> void:
	_resolve_battle_sprite_2d()
	status_handler.status_owner = self
	stats_ui.resized.connect(_schedule_layout_status_bar)
	if is_instance_valid(target_highlight):
		target_highlight.modulate.a = 0.0
		target_highlight.hide()
	_hide_hover_name_immediate()
	if is_instance_valid(stats):
		if Engine.is_editor_hint():
			if Enemy.editor_preview_script_ready(self):
				call_deferred("refresh_editor_battle_preview")
			call_deferred("_sync_status_bar_health_width")
		else:
			_connect_stats_combat_signals(stats)
	if _uses_scene_ui_layout():
		call_deferred("sync_scene_layout_ui")
	else:
		call_deferred("_layout_status_bar")
	if not Engine.is_editor_hint():
		call_deferred("_deferred_connect_intent_tooltip_handlers")
		if not Events.enemy_action_completed.is_connected(_on_own_action_completed_restore_position):
			Events.enemy_action_completed.connect(_on_own_action_completed_restore_position)
	set_process(false)


func capture_battle_home_position() -> void:
	if Engine.is_editor_hint():
		return
	_battle_home_position = position
	_battle_home_global_position = global_position
	_battle_home_captured = true
	Shaker.bind_home(self, _battle_home_position)


func restore_battle_position() -> void:
	if not _battle_home_captured or _death_sequence_started:
		return
	global_position = _battle_home_global_position


func get_battle_home_global_position() -> Vector2:
	if _battle_home_captured:
		return _battle_home_global_position
	return global_position


func _on_own_action_completed_restore_position(completed: Enemy) -> void:
	if completed == self:
		restore_battle_position()


func _uses_scene_ui_layout() -> bool:
	if _enemy_scene_uses_hand_placed_ui():
		return true
	if Engine.is_editor_hint():
		var ed_stats := _editor_resolved_stats()
		if ed_stats != null:
			return ed_stats.uses_scene_ui_layout
		return _scene_ui_layout_flag_from_stats()
	return _scene_ui_layout_flag_from_stats()


## 供 StatusBar 等 UI 节点查询，避免跨脚本调用私有方法。
func uses_scene_ui_layout() -> bool:
	return _uses_scene_ui_layout()


func _enemy_scene_uses_hand_placed_ui() -> bool:
	var path := get_scene_file_path()
	if path.is_empty():
		path = scene_file_path
	return path.ends_with("_enemy.tscn")


func _scene_ui_layout_flag_from_stats() -> bool:
	if not is_instance_valid(stats) or not stats is EnemyStats:
		return false
	if Engine.is_editor_hint() and Stats.is_editor_placeholder(stats):
		return false
	return (stats as EnemyStats).uses_scene_ui_layout


func _enter_tree() -> void:
	_editor_bind_stats_preview_listener()


func _editor_bind_stats_preview_listener() -> void:
	if not Engine.is_editor_hint():
		return
	_editor_unbind_stats_preview_listener()
	var ed_stats := _editor_resolved_stats()
	if ed_stats == null:
		return
	_editor_stats_listener = ed_stats
	if not ed_stats.changed.is_connected(_on_editor_stats_resource_changed):
		ed_stats.changed.connect(_on_editor_stats_resource_changed)


func _editor_unbind_stats_preview_listener() -> void:
	if is_instance_valid(_editor_stats_listener) and _editor_stats_listener.changed.is_connected(_on_editor_stats_resource_changed):
		_editor_stats_listener.changed.disconnect(_on_editor_stats_resource_changed)
	_editor_stats_listener = null


## 在 *_enemy.tscn 中 stats 常为 ExtResource placeholder（resource_path 为空）；从场景路径等推断 .tres 并 load。
func _editor_resolved_stats() -> EnemyStats:
	if not Engine.is_editor_hint():
		return stats if is_instance_valid(stats) else null
	for path in _editor_stats_resource_paths():
		if path.is_empty() or not ResourceLoader.exists(path):
			continue
		var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as EnemyStats
		var resolved := _editor_materialize_stats(loaded)
		if resolved != null:
			return resolved
	if is_instance_valid(stats) and not Stats.is_editor_placeholder(stats):
		var resolved := _editor_materialize_stats(stats)
		if resolved != null:
			return resolved
	return null


static func _editor_materialize_stats(res: EnemyStats) -> EnemyStats:
	if res == null:
		return null
	if _editor_stats_resource_usable(res):
		return res
	var dup := res.duplicate(true) as EnemyStats
	if dup != null and _editor_stats_resource_usable(dup):
		return dup
	return null


static func _editor_stats_resource_usable(res: Stats) -> bool:
	if res == null or not res is EnemyStats:
		return false
	if Engine.is_editor_hint():
		if Stats.is_editor_placeholder(res):
			return false
		if not Stats.is_editor_ui_usable(res):
			return false
	return Callable(res, "build_editor_preview_intents").is_valid()


func _editor_stats_resource_paths() -> PackedStringArray:
	var paths: PackedStringArray = []
	var seen: Dictionary = {}
	var add_path := func(path: String) -> void:
		if path.is_empty() or seen.has(path):
			return
		seen[path] = true
		paths.append(path)
	if is_instance_valid(stats):
		add_path.call(stats.resource_path)
		if stats is EnemyStats:
			var scene_path := SaveGameMigrations.remap_resource_path((stats as EnemyStats).enemy_scene_path.strip_edges())
			if scene_path.ends_with("_enemy.tscn"):
				add_path.call(scene_path.replace("_enemy.tscn", "_enemy.tres"))
				add_path.call(scene_path.replace("_enemy.tscn", ".tres"))
	var owner_scene := get_scene_file_path()
	if owner_scene.is_empty():
		owner_scene = scene_file_path
	if owner_scene.ends_with("_enemy.tscn"):
		add_path.call(owner_scene.replace("_enemy.tscn", "_enemy.tres"))
		add_path.call(owner_scene.replace("_enemy.tscn", ".tres"))
	return paths


func _on_editor_stats_resource_changed() -> void:
	if Enemy.editor_preview_script_ready(self):
		call_deferred("refresh_editor_battle_preview")


func _schedule_layout_status_bar() -> void:
	if _uses_scene_ui_layout():
		_sync_status_bar_health_width()
		return
	call_deferred("_layout_status_bar")


func _sync_status_bar_health_width() -> void:
	var sb := get_node_or_null("StatusBar")
	if sb != null and sb.has_method("sync_health_bar_to_container_width"):
		sb.sync_health_bar_to_container_width()
		return
	var sb_ctrl := get_node_or_null("StatusBar") as Control
	var health_row := get_node_or_null("StatusBar/HealthRow") as HealthBar
	if health_row != null and sb_ctrl != null:
		_sync_health_row_width_from_status_bar_container(health_row)


func _sync_scene_ui_hover_name() -> void:
	if not is_instance_valid(stats_ui) or not is_instance_valid(hover_name_overlay):
		return
	if _hover_name_is_hand_placed():
		return
	if not is_inside_tree():
		return
	var name_ui := _hover_name_ui()
	if name_ui != null:
		name_ui.call_deferred("sync_layout_from_status_bar", stats_ui)


func _hover_name_is_hand_placed() -> bool:
	if not is_instance_valid(hover_name_overlay):
		return false
	if hover_name_overlay.has_meta(&"hand_placed_hover_name"):
		return true
	if hover_name_overlay.has_meta(&"auto_layout_from_status_bar"):
		return false
	# *_enemy.tscn 里生成器留下的 HoverName 占位 offset 不算手摆，默认跟 StatusBar 对齐。
	if _uses_scene_ui_layout():
		return false
	var lbl := hover_name_overlay as Control
	var offset_w := absf(lbl.offset_right - lbl.offset_left)
	var offset_h := absf(lbl.offset_bottom - lbl.offset_top)
	if offset_w >= 1.0 or offset_h >= 1.0:
		return true
	if lbl.position.length_squared() > 1.0:
		return true
	return false


func _deferred_connect_intent_tooltip_handlers() -> void:
	var tree := get_tree()
	if tree:
		IntentUI.ensure_intent_tooltip_handlers_connected(tree)


func _hover_name_ui() -> CombatantHoverName:
	if not is_instance_valid(hover_name_overlay):
		return null
	# 编辑器 placeholder 节点上自定义脚本尚未就绪；运行时无 placeholder。
	if Engine.is_editor_hint() and not hover_name_overlay.has_method("hide_immediate"):
		return null
	return hover_name_overlay


func _hide_hover_name_immediate() -> void:
	var name_ui := _hover_name_ui()
	if name_ui == null:
		return
	name_ui.hide_immediate()


func _process(_delta: float) -> void:
	if not is_inside_tree():
		return
	if Events.is_combat_ended():
		_hide_intent_hover_tooltip_if_active()
		_update_pointer_hover_state()
		return
	if not is_instance_valid(stats) or stats.health <= 0:
		_hide_intent_hover_tooltip_if_active()
		_update_pointer_hover_state()
		return
	_update_pointer_hover_state()
	if not is_instance_valid(intent_ui):
		return
	if current_action == null:
		_hide_intent_hover_tooltip_if_active()
		return
	var planned: Array[Intent] = current_action.get_planned_intents()
	if planned.is_empty() or not intent_ui.visible:
		_hide_intent_hover_tooltip_if_active()
		return
	var viewport := get_viewport()
	var screen_pos := CombatPointer.screen_mouse(viewport)
	var over_body := CombatPointer.node2d_shape_has_world_point(
		self, collision_shape_2d, get_global_mouse_position()
	)
	var over_intent := CombatPointer.control_has_screen_point(intent_ui, screen_pos)
	var over := over_body or over_intent
	if over and Events.is_pointer_ui_obscured_for(intent_ui):
		over = false
	var bb := Intent.build_intent_hover_bbcode(planned)
	if bb.is_empty():
		over = false
	if over:
		if not _intent_hover_tooltip_active:
			IntentUI.ensure_intent_tooltip_handlers_connected(get_tree())
			_intent_hover_tooltip_active = true
			Events.intent_tooltip_hover_show.emit(bb, intent_ui, false)
	elif _intent_hover_tooltip_active:
		_hide_intent_hover_tooltip_if_active()


func _pointer_over_intent_ui(screen_global: Vector2) -> bool:
	return CombatPointer.control_has_screen_point(intent_ui, screen_global)


func _pointer_over_enemy_body(_screen_global: Vector2 = Vector2.ZERO) -> bool:
	return CombatPointer.node2d_shape_has_world_point(
		self, collision_shape_2d, get_global_mouse_position()
	)


func _update_pointer_hover_state() -> void:
	if Engine.is_editor_hint():
		return
	var over := false
	if is_instance_valid(stats) and stats.health > 0 and not Events.is_combat_ended():
		var viewport := get_viewport()
		var screen_pos := CombatPointer.screen_mouse(viewport)
		over = _pointer_over_enemy_body() or _pointer_over_intent_ui(screen_pos)
		if over and is_instance_valid(stats_ui) and Events.is_pointer_ui_obscured_for(stats_ui):
			over = false
	if over == _pointer_hover:
		return
	_pointer_hover = over
	_refresh_interaction_visuals()


func _enemy_has_display_name() -> bool:
	return stats is EnemyStats and not (stats as EnemyStats).get_display_name().is_empty()


func _sync_combatant_hover_name_text() -> void:
	var name_ui := _hover_name_ui()
	if name_ui == null:
		return
	var name_text := ""
	if stats is EnemyStats:
		name_text = (stats as EnemyStats).get_display_name()
	name_ui.set_display_name(name_text)


func _sync_combat_process_enabled() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	if not is_inside_tree() or not is_instance_valid(stats) or stats.health <= 0:
		set_process(false)
		return
	if Events.is_combat_ended():
		set_process(false)
		return
	set_process(true)


func _refresh_interaction_visuals() -> void:
	var show_frame := _pointer_hover or (_card_targeting_active and _card_targeting_valid)
	var show_name := _pointer_hover and _enemy_has_display_name()
	_tween_interaction_visuals(1.0 if show_frame else 0.0, 1.0 if show_name else 0.0)


func _tween_interaction_visuals(frame_alpha: float, name_alpha: float) -> void:
	if is_instance_valid(_interaction_fade_tween):
		_interaction_fade_tween.kill()
	if frame_alpha > 0.0 and is_instance_valid(target_highlight):
		var rect := get_card_targeting_rect_local()
		if rect.has_area():
			target_highlight.setup_from_local_rect(rect)
			target_highlight.show()
	var tw := create_tween()
	_interaction_fade_tween = tw
	tw.set_parallel(true)
	if is_instance_valid(target_highlight):
		tw.tween_property(target_highlight, "modulate:a", frame_alpha, INTERACTION_FADE_SEC)
	if is_instance_valid(hover_name_overlay):
		var name_ui := _hover_name_ui()
		if name_ui != null:
			name_ui.tween_visibility(name_alpha)
	tw.finished.connect(
		func() -> void:
			if is_instance_valid(target_highlight) and target_highlight.modulate.a <= 0.001:
				target_highlight.hide(),
		CONNECT_ONE_SHOT
	)


func _clear_interaction_visuals_immediate() -> void:
	if is_instance_valid(_interaction_fade_tween):
		_interaction_fade_tween.kill()
		_interaction_fade_tween = null
	_pointer_hover = false
	_card_targeting_active = false
	_card_targeting_valid = false
	if is_instance_valid(target_highlight):
		target_highlight.modulate.a = 0.0
		target_highlight.hide()
	_hide_hover_name_immediate()


func _hide_intent_hover_tooltip_if_active() -> void:
	if not _intent_hover_tooltip_active:
		return
	_intent_hover_tooltip_active = false
	Events.intent_tooltip_hover_hide.emit()


func _apply_intent_ui_offset() -> void:
	if not is_instance_valid(intent_ui):
		return
	if _uses_scene_ui_layout():
		return
	var s := _editor_resolved_stats() if Engine.is_editor_hint() else stats
	if s == null:
		return
	var o := s.intent_ui_offset
	intent_ui.offset_left = _INTENT_UI_BASE_LEFT + o.x
	intent_ui.offset_right = _INTENT_UI_BASE_RIGHT + o.x
	intent_ui.offset_top = _INTENT_UI_BASE_TOP - o.y
	intent_ui.offset_bottom = _INTENT_UI_BASE_BOTTOM - o.y


func refresh_editor_battle_preview() -> void:
	if not Engine.is_editor_hint():
		return
	if not Callable(self, "_finish_editor_battle_preview").is_valid():
		return
	call_deferred("_finish_editor_battle_preview")


static func editor_preview_script_ready(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if not node is Enemy:
		return false
	var scr: Script = node.get_script() as Script
	if scr == null or not scr is GDScript:
		return false
	if not (scr as GDScript).is_tool():
		return false
	return Callable(node, "refresh_editor_battle_preview").is_valid()


static func request_editor_battle_preview(node: Node) -> void:
	if not editor_preview_script_ready(node):
		return
	Callable(node, "refresh_editor_battle_preview").call_deferred()


func _apply_editor_battle_preview() -> void:
	refresh_editor_battle_preview()


func _finish_editor_battle_preview() -> void:
	if not Engine.is_editor_hint():
		return
	_resolve_editor_sprite_2d()
	if is_instance_valid(stats_ui) and stats_ui.has_method("uses_scene_container_width"):
		if stats_ui.uses_scene_container_width() and stats_ui.has_method("sync_health_bar_to_container_width"):
			stats_ui.sync_health_bar_to_container_width()
	var ed_stats := _editor_resolved_stats()
	if is_instance_valid(stats_ui) and ed_stats != null:
		_apply_editor_battle_ui_preview(ed_stats)
	if ed_stats == null or not is_instance_valid(sprite_2d):
		queue_redraw()
		return
	_stop_art_animation()
	_apply_editor_static_art()
	if ed_stats is EnemyStats:
		_apply_art_scale_from_stats()
	if is_instance_valid(arrow):
		arrow.hide()
	_sync_hitbox_to_sprite()
	queue_redraw()


func _apply_editor_battle_ui_preview(ed_stats: EnemyStats) -> void:
	if ed_stats.uses_scene_ui_layout:
		sync_scene_layout_ui()
		return
	var health_row := _get_health_bar_row()
	if health_row is HealthBar:
		var hb := health_row as HealthBar
		_sync_health_row_width_from_status_bar_container(hb)
		hb.commit_bar_width_to_host(0)
		hb.ensure_theme_ready()
	var preview := _editor_preview_stats()
	if preview != null and is_instance_valid(stats_ui):
		if health_row is HealthBar:
			(health_row as HealthBar).ensure_theme_ready()
		stats_ui.update_stats(preview)
	_sync_scene_editor_health_bar_preview()
	_apply_intent_ui_offset()
	_layout_status_bar()
	_apply_editor_preview_intents()
	call_deferred("_layout_status_bar")
	if is_instance_valid(stats_ui):
		stats_ui.queue_sort()
		stats_ui.queue_redraw()
	if is_instance_valid(intent_ui):
		intent_ui.queue_sort()
		intent_ui.queue_redraw()


func _resolved_intent_ui() -> IntentUI:
	if is_instance_valid(intent_ui):
		return intent_ui
	return get_node_or_null("IntentUI") as IntentUI


func _apply_editor_preview_intents() -> void:
	var ui := _resolved_intent_ui()
	if ui == null:
		return
	var ed_stats := _editor_resolved_stats()
	if ed_stats == null or not _editor_stats_resource_usable(ed_stats):
		_sync_scene_intent_slots([])
		return
	var intents := ed_stats.build_editor_preview_intents(self, editor_preview_action)
	if ed_stats.uses_scene_ui_layout:
		_sync_scene_intent_slots(intents)
		return
	intents = _finalize_editor_preview_intents(intents)
	ui.update_intents(intents)


func _sync_scene_intent_slots(intents: Array[Intent]) -> void:
	var ui := _resolved_intent_ui()
	if ui == null:
		return
	if not Engine.is_editor_hint() and intents.is_empty():
		ui.hide()
		for child in ui.get_children():
			if child is IntentSlot:
				(child as IntentSlot).hide()
		return
	if Engine.is_editor_hint():
		intents = _finalize_editor_preview_intents(intents)
	var display := Intent.merge_by_kind_for_display(intents)
	var slots: Array[IntentSlot] = []
	for child in ui.get_children():
		if child is IntentSlot:
			slots.append(child as IntentSlot)
	while slots.size() > display.size():
		var extra: IntentSlot = slots.pop_back()
		ui.remove_child(extra)
		extra.queue_free()
	while slots.size() < display.size():
		var slot: IntentSlot = IntentUI.INTENT_SLOT.instantiate() as IntentSlot
		slot.name = "EditorPreviewIntentSlot%d" % slots.size()
		ui.add_child(slot)
		if Engine.is_editor_hint():
			slot.owner = ui.owner if ui.owner else self
		slots.append(slot)
	for i in display.size():
		slots[i].setup(display[i])
		slots[i].show()
	if display.is_empty():
		ui.hide()
	else:
		ui.show()


func _resolve_editor_sprite_2d() -> void:
	_resolve_battle_sprite_2d()


## 指向实际战斗贴图（跳过隐藏占位 Sprite2D、箭矢、水纹等装饰）。
func _resolve_battle_sprite_2d() -> void:
	if _is_primary_battle_sprite(sprite_2d):
		return
	for node in find_children("*", "Sprite2D", true, false):
		var candidate := node as Sprite2D
		if _is_primary_battle_sprite(candidate):
			sprite_2d = candidate
			return


func _is_primary_battle_sprite(sprite: Sprite2D) -> bool:
	if not is_instance_valid(sprite) or sprite == arrow:
		return false
	if not sprite.visible or sprite.texture == null:
		return false
	var label := str(sprite.get_path()) if sprite.is_inside_tree() else str(sprite.name)
	if "Shallows" in label or "BlockBadge" in label:
		return false
	return true


func _apply_art_scale_from_stats() -> void:
	# *_enemy.tscn：贴图缩放完全以场景内手调为准（Visual / Body / Sprite2D 等）。
	if _enemy_scene_uses_hand_placed_ui():
		return
	if stats is EnemyStats and is_instance_valid(sprite_2d):
		sprite_2d.scale = (stats as EnemyStats).art_scale


func _finalize_editor_preview_intents(intents: Array[Intent]) -> Array[Intent]:
	if intents.is_empty():
		return [_make_default_editor_attack_preview_intent()]
	var out: Array[Intent] = []
	for intent in intents:
		if intent == null:
			continue
		var mat := Intent.editor_materialize(intent) if Engine.is_editor_hint() else intent
		if mat == null:
			continue
		if mat.kind == Intent.Kind.ATTACK:
			if mat.display_number == Intent.NUMBER_HIDDEN and mat.current_text.is_empty():
				mat.set_attack_segments_display(10, 1)
		out.append(mat)
	return out


static func _make_default_editor_attack_preview_intent() -> Intent:
	var intent := Intent.new()
	intent.kind = Intent.Kind.ATTACK
	intent.set_attack_segments_display(10, 1)
	return intent


func _apply_editor_static_art() -> void:
	var ed_stats := _editor_resolved_stats() if Engine.is_editor_hint() else stats
	if ed_stats == null or not is_instance_valid(sprite_2d):
		return
	if Engine.is_editor_hint():
		if ed_stats.art_frames.size() >= 1:
			sprite_2d.texture = ed_stats.art_frames[0]
		elif ed_stats.art:
			sprite_2d.texture = ed_stats.art
		return
	if _uses_sequence_art() and ed_stats.art_frames.size() > 0:
		sprite_2d.texture = ed_stats.art_frames[0]
	elif ed_stats.art_frames.size() >= 1:
		sprite_2d.texture = ed_stats.art_frames[0]
	elif ed_stats.art:
		sprite_2d.texture = ed_stats.art


func _editor_preview_stats() -> Stats:
	var source := _editor_resolved_stats()
	if source == null or not _editor_stats_resource_usable(source):
		return null
	var preview := source.duplicate(true) as Stats
	if preview == null or preview.max_health <= 0:
		return null
	preview.set("health", preview.max_health)
	preview.set("block", 0)
	return preview


## 场景布局敌人：只同步血条宽度与数值，不改动 tscn 里手摆的 StatusBar / IntentUI 位置。
func sync_scene_layout_ui() -> void:
	if not _uses_scene_ui_layout():
		return
	if is_instance_valid(stats_ui) and stats_ui.has_method("sync_health_bar_to_container_width"):
		stats_ui.sync_health_bar_to_container_width()
	var health_row := _get_health_bar_row()
	if health_row is HealthBar:
		var hb := health_row as HealthBar
		hb.show_max_hp = true
		_sync_health_row_width_from_status_bar_container(hb)
		hb.commit_bar_width_to_host(0)
		hb.ensure_theme_ready()
	if Engine.is_editor_hint():
		var preview := _editor_preview_stats()
		if preview != null and is_instance_valid(stats_ui):
			stats_ui.update_stats(preview)
		_apply_editor_preview_intents()
	elif is_instance_valid(stats) and is_instance_valid(stats_ui):
		stats_ui.update_stats(stats)
	if not _hover_name_is_hand_placed():
		_sync_scene_ui_hover_name()
	_ensure_status_bar_draw_order()
	if is_instance_valid(stats_ui):
		stats_ui.queue_sort()
		stats_ui.queue_redraw()
	if is_instance_valid(intent_ui):
		intent_ui.queue_sort()
		intent_ui.queue_redraw()


func _ensure_status_bar_draw_order() -> void:
	if not _uses_scene_ui_layout() or not is_instance_valid(stats_ui):
		return
	stats_ui.z_as_relative = true
	stats_ui.z_index = SCENE_LAYOUT_STATUS_BAR_Z
	var name_ui := _hover_name_ui()
	if name_ui != null:
		name_ui.z_as_relative = true
		name_ui.z_index = CombatantHoverName.DRAW_Z_INDEX
		move_child(name_ui, get_child_count() - 1)


func _layout_status_bar() -> void:
	if not is_instance_valid(stats_ui):
		return
	if _uses_scene_ui_layout():
		_sync_status_bar_health_width()
		_ensure_status_bar_draw_order()
		if is_inside_tree() and not _hover_name_is_hand_placed():
			_sync_scene_ui_hover_name()
		return
	if not is_instance_valid(sprite_2d):
		return
	var s := _editor_resolved_stats() if Engine.is_editor_hint() else stats
	if s == null:
		return
	var foot_y := _sprite_foot_local_y()
	var off := s.status_bar_offset
	var w := maxf(stats_ui.size.x, stats_ui.get_combined_minimum_size().x)
	stats_ui.position = Vector2(-w * 0.5 + off.x, foot_y + off.y)
	if is_instance_valid(hover_name_overlay):
		var name_ui := _hover_name_ui()
		if name_ui != null:
			name_ui.call_deferred("sync_layout_from_status_bar", stats_ui)


func _get_health_bar_row() -> HealthBar:
	if not is_instance_valid(stats_ui):
		return null
	return stats_ui.get_node_or_null("HealthRow") as HealthBar


## 血条宽度以 StatusBar 容器为准（拉伸 StatusBar 时实时同步 BarHost）。
func _sync_health_row_width_from_status_bar_container(health_row: HealthBar) -> void:
	if health_row == null or not is_instance_valid(stats_ui):
		return
	if stats_ui is StatusBar and stats_ui.has_method("uses_scene_container_width"):
		if not (stats_ui as StatusBar).uses_scene_container_width():
			return
	if stats_ui.has_method("sync_health_bar_to_container_width"):
		stats_ui.sync_health_bar_to_container_width()
		return
	if stats_ui.has_method("read_container_width"):
		var sb_w: int = stats_ui.read_container_width()
		if sb_w > 0:
			health_row.apply_width_from_status_bar_container(sb_w)
			return
	var sb_w := HealthBar.read_status_bar_container_width(stats_ui)
	if sb_w > 0:
		health_row.apply_width_from_status_bar_container(sb_w)


func _resolved_health_bar_width() -> float:
	if stats == null:
		return 180.0
	if stats.uses_scene_ui_layout:
		var health_row := _get_health_bar_row()
		if health_row != null:
			return float(health_row.get_authoritative_bar_width(0))
	var bw := float(HealthBar.clamp_bar_width(stats.health_bar_width))
	return bw


func _sync_scene_editor_health_bar_preview() -> void:
	if not Engine.is_editor_hint():
		return
	var ed_stats := _editor_resolved_stats()
	if ed_stats == null or not ed_stats.uses_scene_ui_layout:
		return
	var health_row := _get_health_bar_row()
	if health_row == null:
		return
	health_row.show_max_hp = true
	var preview := _editor_preview_stats()
	if preview == null:
		return
	health_row.ensure_theme_ready()
	health_row.update_stats(preview)


func _sprite_foot_local_y() -> float:
	if sprite_2d.texture == null:
		return 40.0
	var r := sprite_2d.get_rect()
	return sprite_2d.position.y + r.position.y + r.size.y


func _floating_number_anchor_local() -> Vector2:
	if not is_instance_valid(sprite_2d) or sprite_2d.texture == null:
		return Vector2(0, -48)
	var r := sprite_2d.get_rect()
	var cx := sprite_2d.position.x + r.get_center().x
	var top := sprite_2d.position.y + r.position.y
	return Vector2(cx, top - 6.0)


func _connect_stats_combat_signals(s: Stats) -> void:
	if s == null:
		return
	if not s.unblocked_damage_taken.is_connected(_on_stats_unblocked_damage_taken):
		s.unblocked_damage_taken.connect(_on_stats_unblocked_damage_taken)
	if not s.healing_applied.is_connected(_on_stats_healing_applied):
		s.healing_applied.connect(_on_stats_healing_applied)
	s.filter_unblocked_hp_loss = _filter_unblocked_hp_loss_for_hard_shell


func _disconnect_stats_combat_signals(s: Stats) -> void:
	if s == null:
		return
	if s.unblocked_damage_taken.is_connected(_on_stats_unblocked_damage_taken):
		s.unblocked_damage_taken.disconnect(_on_stats_unblocked_damage_taken)
	if s.healing_applied.is_connected(_on_stats_healing_applied):
		s.healing_applied.disconnect(_on_stats_healing_applied)
	s.filter_unblocked_hp_loss = Callable()


func _filter_unblocked_hp_loss_for_hard_shell(hp_loss: int) -> int:
	var hard_shell := HardShellStatus.get_on_enemy(self)
	if hard_shell == null:
		return hp_loss
	return hard_shell.try_allow_hp_loss(hp_loss, self)


func _on_stats_unblocked_damage_taken(amount: int) -> void:
	FloatingCombatNumber.spawn(self, _floating_number_anchor_local(), amount, Color.WHITE)
	var heavy_armor := HeavyArmorStatus.get_on_enemy(self)
	if heavy_armor != null and amount > 0:
		heavy_armor.register_damage_taken(amount, self)
	if _pending_player_attack_card_hits > 0:
		if amount > 0:
			LayeredArmorStatus.on_unblocked_attack_damage(self, amount)
		_pending_player_attack_card_hits -= 1
		if amount > 0 and not Events.is_combat_ended():
			Events.player_dealt_attack_damage_to_enemy.emit(self, amount)


func _on_stats_healing_applied(amount: int) -> void:
	FloatingCombatNumber.spawn(self, _floating_number_anchor_local(), amount, HEAL_FLOAT_COLOR)


func set_current_action(value: EnemyAction) -> void:
	if current_action == value:
		return
	current_action = value
	if not _skip_intent_on_action_assign:
		update_intent()


func _set_current_action_silent(value: EnemyAction) -> void:
	if current_action == value:
		return
	_skip_intent_on_action_assign = true
	current_action = value
	_skip_intent_on_action_assign = false


func set_editor_preview_action(value: StringName) -> void:
	if editor_preview_action == value:
		return
	editor_preview_action = value
	if Engine.is_editor_hint() and Enemy.editor_preview_script_ready(self):
		call_deferred("refresh_editor_battle_preview")


func set_enemy_stats(value: EnemyStats) -> void:
	if is_instance_valid(stats) and not Engine.is_editor_hint():
		_disconnect_stats_combat_signals(stats)
	if not is_instance_valid(value):
		stats = null
		_fixed_sprite_hitbox_local = Rect2()
		_hitbox_locked = false
		return
	_fixed_sprite_hitbox_local = Rect2()
	_hitbox_locked = false
	if Engine.is_editor_hint():
		_editor_unbind_stats_preview_listener()
		stats = value
		_editor_bind_stats_preview_listener()
		refresh_editor_battle_preview()
		return
	stats = value.create_instance() as EnemyStats
	_connect_stats_combat_signals(stats)
	
	if not stats.stats_changed.is_connected(update_stats):
		stats.stats_changed.connect(update_stats)
		stats.stats_changed.connect(update_action)
	
	update_enemy()


## 战斗生成后再同步一次贴图缩放，避免 stats 赋值早于 @onready / 子类 repoint sprite。
func _apply_battle_spawn_visuals() -> void:
	if not is_instance_valid(stats):
		return
	_resolve_battle_sprite_2d()
	if not _enemy_scene_uses_hand_placed_ui():
		_apply_art_scale_from_stats()
	if stats is EnemyStats:
		(stats as EnemyStats).setup_battle_visual(self)
	if not is_instance_valid(sprite_2d):
		return
	_sync_hitbox_to_sprite()
	var half_width := sprite_2d.get_rect().size.x * absf(sprite_2d.scale.x) * 0.5
	if is_instance_valid(arrow):
		arrow.position = Vector2.RIGHT * (half_width + ARROW_OFFSET)
	capture_battle_home_position()


func setup_ai() -> void:
	if enemy_action_picker:
		enemy_action_picker.queue_free()
		
	var new_action_picker := stats.ai.instantiate() as EnemyActionPicker
	add_child(new_action_picker)
	enemy_action_picker = new_action_picker
	enemy_action_picker.enemy = self


func update_stats() -> void:
	if _uses_scene_ui_layout():
		sync_scene_layout_ui()
		return
	if Engine.is_editor_hint():
		return
	stats_ui.update_stats(stats)
	_layout_status_bar()


func update_action(show_intent: bool = true) -> void:
	if not enemy_action_picker:
		return
	
	if not current_action:
		var action := enemy_action_picker.get_action()
		if show_intent:
			current_action = action
		else:
			_set_current_action_silent(action)
		return
	
	var new_conditional_action := enemy_action_picker.get_first_conditional_action()
	if new_conditional_action and current_action != new_conditional_action:
		if show_intent:
			current_action = new_conditional_action
		else:
			_set_current_action_silent(new_conditional_action)


func update_enemy() -> void:
	if not stats is Stats: 
		return
	if not is_inside_tree(): 
		await ready
	
	_resolve_battle_sprite_2d()
	_apply_enemy_art()
	_apply_art_scale_from_stats()
	var half_width := sprite_2d.get_rect().size.x * absf(sprite_2d.scale.x) * 0.5
	arrow.position = Vector2.RIGHT * (half_width + ARROW_OFFSET)
	_sync_hitbox_to_sprite()
	setup_ai()
	update_stats()
	_apply_intent_ui_offset()
	call_deferred("_apply_intent_ui_offset")
	_sync_combatant_hover_name_text()
	if not Engine.is_editor_hint():
		_sync_combat_process_enabled()


## 单体牌瞄准依赖与敌人 `Area2D` 的重叠；按贴图 **alpha>阈值** 的实体像素做 AABB，避免整块画布透明边也被当成目标。
func _sync_hitbox_to_sprite() -> void:
	if _hitbox_locked:
		return
	_apply_hitbox_shape_from_sprite_bounds()


func _apply_hitbox_shape_from_sprite_bounds() -> void:
	if not is_instance_valid(collision_shape_2d) or not is_instance_valid(sprite_2d) or sprite_2d.texture == null:
		return
	var r_sprite := _sprite_local_bounds_for_hitbox()
	var xf := sprite_2d.transform
	var corners: Array[Vector2] = [
		xf * r_sprite.position,
		xf * (r_sprite.position + Vector2(r_sprite.size.x, 0.0)),
		xf * (r_sprite.position + Vector2(0.0, r_sprite.size.y)),
		xf * (r_sprite.position + r_sprite.size),
	]
	var min_v: Vector2 = corners[0]
	var max_v: Vector2 = corners[0]
	for p in corners:
		min_v = min_v.min(p)
		max_v = max_v.max(p)
	var prev := collision_shape_2d.shape as RectangleShape2D
	if prev == null:
		return
	min_v -= Vector2(HITBOX_PAD_PX, HITBOX_PAD_PX)
	max_v += Vector2(HITBOX_PAD_PX, HITBOX_PAD_PX)
	var new_size := max_v - min_v
	var new_pos := (min_v + max_v) * 0.5
	if prev.size.is_equal_approx(new_size) and collision_shape_2d.position.is_equal_approx(new_pos):
		return
	var rect_shape := prev.duplicate() as RectangleShape2D
	rect_shape.size = new_size
	collision_shape_2d.shape = rect_shape
	collision_shape_2d.position = new_pos
	collision_shape_2d.scale = Vector2.ONE


## `Sprite2D` 局部坐标下用于碰撞的轴对齐矩形（优先不透明像素，否则整张贴图 `get_rect()`）。
func _sprite_local_bounds_for_hitbox() -> Rect2:
	if _fixed_sprite_hitbox_local.has_area():
		return _fixed_sprite_hitbox_local
	var opaque := _opaque_bounds_rect_sprite_local(sprite_2d)
	if opaque.has_area():
		return opaque
	return sprite_2d.get_rect()


## 多帧立绘：取全部 `art_frames` 不透明区域并集作为固定瞄准盒（sprite 局部坐标）。
func apply_fixed_hitbox_from_art_frames(frames: Array[Texture]) -> void:
	if not is_instance_valid(sprite_2d) or frames.is_empty():
		return
	var union := _union_opaque_bounds_for_art_frames(sprite_2d, frames)
	if not union.has_area():
		return
	_fixed_sprite_hitbox_local = union
	_apply_hitbox_shape_from_sprite_bounds()
	_hitbox_locked = true
	_update_arrow_from_hitbox()


func get_aim_point_global() -> Vector2:
	if not is_instance_valid(sprite_2d) or sprite_2d.texture == null:
		return global_position
	var r := _sprite_local_bounds_for_hitbox()
	return to_global(sprite_2d.transform * r.get_center())


func get_card_targeting_rect_local() -> Rect2:
	if not is_instance_valid(stats) or stats.health <= 0:
		return Rect2()
	if not is_instance_valid(stats_ui) or not is_instance_valid(intent_ui):
		return Rect2()
	var intent_gr := intent_ui.get_global_rect()
	var intent_bottom_local := to_local(intent_gr.position + Vector2(0.0, intent_gr.size.y))
	var y_top := intent_bottom_local.y
	var w := _resolved_health_bar_width()
	var health_row := _get_health_bar_row()
	var health_top_local: Vector2
	var cx: float
	if health_row != null and is_instance_valid(health_row.bar_host):
		var bar_gr := health_row.bar_host.get_global_rect()
		health_top_local = to_local(bar_gr.position)
		cx = to_local(bar_gr.position + Vector2(bar_gr.size.x * 0.5, 0.0)).x
		w = maxf(w, bar_gr.size.x)
	else:
		var health_ctrl := stats_ui.get_node_or_null("HealthRow") as Control
		if not is_instance_valid(health_ctrl):
			return Rect2()
		var health_gr := health_ctrl.get_global_rect()
		health_top_local = to_local(health_gr.position)
		cx = to_local(health_gr.position + Vector2(health_gr.size.x * 0.5, 0.0)).x
	var y_bottom := health_top_local.y
	var h := y_bottom - y_top
	if h <= 0.0:
		return Rect2()
	return Rect2(cx - w * 0.5, y_top, w, h)


func get_card_targeting_rect_global() -> Rect2:
	var local := get_card_targeting_rect_local()
	if not local.has_area():
		return Rect2()
	var p0 := to_global(local.position)
	var p1 := to_global(local.position + Vector2(local.size.x, 0.0))
	var p2 := to_global(local.position + Vector2(0.0, local.size.y))
	var p3 := to_global(local.position + local.size)
	var min_v := p0.min(p1).min(p2).min(p3)
	var max_v := p0.max(p1).max(p2).max(p3)
	return Rect2(min_v, max_v - min_v)


func set_card_targeting_feedback(active: bool, is_valid_target: bool, _mouse_global: Vector2) -> void:
	_card_targeting_active = active
	_card_targeting_valid = is_valid_target
	if is_instance_valid(arrow):
		arrow.hide()
	_refresh_interaction_visuals()


func _update_arrow_from_hitbox() -> void:
	if not is_instance_valid(sprite_2d) or not is_instance_valid(arrow):
		return
	var r := _sprite_local_bounds_for_hitbox()
	if not r.has_area():
		return
	var right_local := sprite_2d.transform * Vector2(r.position.x + r.size.x, r.get_center().y)
	arrow.position = Vector2.RIGHT * (right_local.x + ARROW_OFFSET)


static func _union_opaque_bounds_for_art_frames(sprite: Sprite2D, frames: Array[Texture]) -> Rect2:
	if sprite == null or frames.is_empty():
		return Rect2()
	var saved_tex := sprite.texture
	var union := Rect2()
	for tex: Texture in frames:
		if tex == null:
			continue
		sprite.texture = tex
		var bounds := _opaque_bounds_rect_sprite_local(sprite)
		if not bounds.has_area():
			continue
		union = bounds if not union.has_area() else union.merge(bounds)
	sprite.texture = saved_tex
	return union


## 在 Sprite2D 局部空间中，不透明像素相对当前 `get_rect()` 绘制域的包围盒；失败返回空 Rect2（`has_area()` 为 false）。
static func _opaque_bounds_rect_sprite_local(sprite: Sprite2D) -> Rect2:
	var tex := sprite.texture
	if tex == null:
		return Rect2()
	var scan: Rect2i
	var base_img: Image
	if tex is AtlasTexture:
		var at := tex as AtlasTexture
		base_img = at.atlas.get_image()
		if base_img.get_width() < 1 or base_img.get_height() < 1:
			return Rect2()
		scan = Rect2i(at.region.position, at.region.size)
		if sprite.region_enabled:
			scan = scan.intersection(Rect2i(sprite.region_rect))
	else:
		base_img = tex.get_image()
		if base_img.get_width() < 1 or base_img.get_height() < 1:
			return Rect2()
		var full := Rect2i(0, 0, base_img.get_width(), base_img.get_height())
		if sprite.region_enabled:
			scan = Rect2i(sprite.region_rect).intersection(full)
		else:
			scan = full
	if scan.size.x < 1 or scan.size.y < 1:
		return Rect2()
	var work: Image = base_img.duplicate() as Image
	if work.get_width() < 1 or work.get_height() < 1:
		return Rect2()
	work.decompress()
	if work.get_format() != Image.FORMAT_RGBA8:
		work.convert(Image.FORMAT_RGBA8)
	var cache_key := _opaque_texel_cache_key(tex, scan)
	var opaque_texel: Rect2i
	if _opaque_texel_aabb_cache.has(cache_key):
		opaque_texel = _opaque_texel_aabb_cache[cache_key] as Rect2i
	else:
		opaque_texel = _scan_opaque_texel_aabb(work, scan, HITBOX_ALPHA_THRESHOLD)
		_opaque_texel_aabb_cache[cache_key] = opaque_texel
	if opaque_texel.size.x < 1 or opaque_texel.size.y < 1:
		return Rect2()
	var reg := Rect2(Vector2(scan.position), Vector2(scan.size))
	return _map_texel_aabb_to_sprite_local(sprite, opaque_texel, reg)


static func _opaque_texel_cache_key(tex: Texture2D, scan: Rect2i) -> String:
	var p := tex.resource_path if tex.resource_path else str(tex.get_rid().get_id())
	return "%s|%d,%d|%dx%d" % [p, scan.position.x, scan.position.y, scan.size.x, scan.size.y]


static func _scan_opaque_texel_aabb(img: Image, scan: Rect2i, alpha_threshold: float) -> Rect2i:
	var min_x := 2147483647
	var min_y := min_x
	var max_x := -2147483648
	var max_y := max_x
	var x1 := scan.position.x + scan.size.x
	var y1 := scan.position.y + scan.size.y
	for y in range(scan.position.y, y1):
		for x in range(scan.position.x, x1):
			if img.get_pixel(x, y).a > alpha_threshold:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < min_x:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


static func _map_texel_aabb_to_sprite_local(sprite: Sprite2D, opaque: Rect2i, reg: Rect2) -> Rect2:
	var dr := sprite.get_rect()
	if reg.size.x <= 0.0 or reg.size.y <= 0.0:
		return dr
	var fx0 := (float(opaque.position.x) - reg.position.x) / reg.size.x
	var fx1 := (float(opaque.end.x) - reg.position.x) / reg.size.x
	var fy0 := (float(opaque.position.y) - reg.position.y) / reg.size.y
	var fy1 := (float(opaque.end.y) - reg.position.y) / reg.size.y
	var p0 := dr.position + Vector2(fx0 * dr.size.x, fy0 * dr.size.y)
	var p1 := dr.position + Vector2(fx1 * dr.size.x, fy1 * dr.size.y)
	return Rect2(p0, p1 - p0).abs()


func clear_intent_display() -> void:
	_intent_suppressed = false
	_apply_intent_ui_hidden()
	_set_current_action_silent(null)


func is_intent_suppressed() -> bool:
	return _intent_suppressed


func _apply_intent_ui_hidden() -> void:
	if is_instance_valid(intent_ui):
		if _uses_scene_ui_layout():
			_sync_scene_intent_slots([])
		else:
			intent_ui.update_intents([])
	_hide_intent_hover_tooltip_if_active()
	_sync_combat_process_enabled()


func is_intent_display_visible() -> bool:
	return is_instance_valid(intent_ui) and intent_ui.visible


func update_intent() -> void:
	if not is_inside_tree():
		return
	var handler := get_parent() as EnemyHandler
	if handler == null:
		handler = get_tree().get_first_node_in_group("enemy_handler") as EnemyHandler
	if handler != null and handler.is_intent_reveal_pending():
		return
	if _intent_suppressed:
		_apply_intent_ui_hidden()
		return
	var planned: Array[Intent] = []
	if current_action:
		current_action.update_planned_intents()
		planned = current_action.get_planned_intents()
	if _uses_scene_ui_layout():
		_sync_scene_intent_slots(planned)
	else:
		intent_ui.update_intents(planned)
	if planned.is_empty():
		_hide_intent_hover_tooltip_if_active()
	_sync_combat_process_enabled()


func do_turn() -> void:
	if not is_instance_valid(stats):
		return
	_hide_intent_hover_tooltip_if_active()

	if not current_action:
		return

	if is_instance_valid(intent_ui) and intent_ui.visible and intent_ui.get_child_count() > 0:
		await intent_ui.play_action_start_animation()

	if not is_instance_valid(self) or not is_instance_valid(current_action):
		return

	_intent_suppressed = true
	current_action.perform_action()
	await _await_self_action_completed()
	_apply_intent_ui_hidden()


## 玩家回合内迅捷等插队：播放意图动画并等待本次 `perform_action` 结束。
func execute_current_action_interrupt() -> void:
	if not is_instance_valid(current_action):
		return
	if is_instance_valid(intent_ui) and intent_ui.visible and intent_ui.get_child_count() > 0:
		await intent_ui.play_action_start_animation()
	if not is_instance_valid(self) or not is_instance_valid(current_action):
		return
	_awaiting_interrupt_action = true
	if not Events.enemy_action_completed.is_connected(_on_interrupt_action_completed):
		Events.enemy_action_completed.connect(_on_interrupt_action_completed)
	current_action.perform_action()
	if _awaiting_interrupt_action:
		await _await_interrupt_action_done()
	if Events.enemy_action_completed.is_connected(_on_interrupt_action_completed):
		Events.enemy_action_completed.disconnect(_on_interrupt_action_completed)


func _on_interrupt_action_completed(completed_enemy: Enemy) -> void:
	if completed_enemy == self:
		_awaiting_interrupt_action = false


func _await_interrupt_action_done() -> void:
	while _awaiting_interrupt_action and is_instance_valid(self) and not Events.is_combat_ended():
		if is_instance_valid(stats) and stats.health <= 0:
			_awaiting_interrupt_action = false
			return
		await Events.enemy_action_completed


func _await_self_action_completed() -> void:
	while is_instance_valid(self) and not Events.is_combat_ended():
		if is_instance_valid(stats) and stats.health <= 0:
			return
		var completed_enemy: Enemy = await Events.enemy_action_completed
		if completed_enemy == self:
			return


func _apply_damage_tween(damage: int) -> void:
	if not is_instance_valid(self) or _death_sequence_started or stats.health <= 0:
		if _pending_player_attack_card_hits > 0 and damage <= 0:
			_pending_player_attack_card_hits -= 1
		return
	if _pending_player_attack_card_hits > 0 and damage <= 0:
		_pending_player_attack_card_hits -= 1
	_apply_damage_to_stats(damage)


func _play_damage_shake() -> void:
	if not is_instance_valid(self) or _death_sequence_started:
		return
	Shaker.shake(self, 72, 0.15)


func _on_take_damage_tween_finished() -> void:
	if not is_instance_valid(self) or _death_sequence_started:
		return
	restore_battle_position()
	sprite_2d.material = null
	if stats.health <= 0:
		_death_sequence_started = true
		_clear_interaction_visuals_immediate()
		Events.enemy_died.emit(self)
		if stats is SpookEnemyStats and not Events.is_player_turn_start_resolving() and not Events.is_combat_ended():
			Events.player_combat_stat_context_changed.emit()
		queue_free()


func _apply_damage_to_stats(damage: int) -> void:
	if is_instance_valid(stats):
		stats.take_damage(damage)


func take_damage(damage: int, which_modifier: Modifier.Type) -> void:
	if stats.health <= 0 or _death_sequence_started:
		return
	
	if (
		which_modifier == Modifier.Type.DMG_TAKEN
		and Events.is_inside_attack_card_effects()
	):
		_pending_player_attack_card_hits += 1
	
	sprite_2d.material = WHITE_SPRITE_MATERIAL
	var modified_damage: int
	if (
		which_modifier == Modifier.Type.DMG_TAKEN
		and Events.is_inside_attack_card_effects()
	):
		var p := get_tree().get_first_node_in_group("battle_player") as Player
		modified_damage = EnemyIncomingAttackDamage.compute(damage, self, p)
		if p:
			modified_damage = OverwhelmingStatus.apply_multiplier_to_final_attack_damage(p, modified_damage)
	elif which_modifier == Modifier.Type.DMG_TAKEN:
		var p := get_tree().get_first_node_in_group("battle_player") as Player
		modified_damage = EnemyIncomingAttackDamage.compute(damage, self, p)
	else:
		modified_damage = modifier_handler.get_modified_value(damage, which_modifier)
	
	var damage_to_apply := modified_damage
	var heavy_armor := HeavyArmorStatus.get_on_enemy(self)
	if heavy_armor != null:
		damage_to_apply = heavy_armor.clamp_incoming_damage(modified_damage, stats.block)
	
	var tween := create_tween()
	tween.tween_callback(_play_damage_shake)
	tween.tween_callback(_apply_damage_tween.bind(damage_to_apply))
	tween.tween_interval(0.17)
	tween.finished.connect(_on_take_damage_tween_finished, CONNECT_ONE_SHOT)


func set_display_texture(tex: Texture2D) -> void:
	if not is_instance_valid(sprite_2d) or tex == null:
		return
	_stop_art_animation()
	sprite_2d.texture = tex
	_sync_hitbox_to_sprite()
	var half_width := sprite_2d.get_rect().size.x * absf(sprite_2d.scale.x) * 0.5
	arrow.position = Vector2.RIGHT * (half_width + ARROW_OFFSET)


func _apply_enemy_art() -> void:
	if _uses_sequence_art():
		_begin_sequence_art()
		return
	if stats.art_frames.size() >= 2:
		_art_frame_index = 0
		sprite_2d.texture = stats.art_frames[0]
		_start_art_animation()
	else:
		_stop_art_animation()
		sprite_2d.texture = stats.art


func _uses_sequence_art() -> bool:
	if stats is LittleSkeltonEnemyStats:
		return (stats as LittleSkeltonEnemyStats).uses_multi_sequence_art()
	if stats is CrabEnemyStats:
		return (stats as CrabEnemyStats).uses_multi_sequence_art()
	if stats is RatEnemyStats:
		return (stats as RatEnemyStats).uses_multi_sequence_art()
	return false


func _begin_sequence_art() -> void:
	_skelton_art_sequence = _pick_sequence_art(false)
	_skelton_art_seq_step = 0
	_apply_sequence_art_frame()
	_start_sequence_art_animation()


func _pick_sequence_art(advance_cycle: bool) -> PackedInt32Array:
	if stats is LittleSkeltonEnemyStats:
		var skel_stats := stats as LittleSkeltonEnemyStats
		if advance_cycle:
			var seq := skel_stats.pick_art_sequence(_skelton_last_was_long_seq)
			_skelton_last_was_long_seq = LittleSkeltonEnemyStats.is_long_sequence(seq)
			return seq
		return skel_stats.pick_art_sequence()
	if stats is CrabEnemyStats:
		return (stats as CrabEnemyStats).pick_art_sequence()
	if stats is RatEnemyStats:
		var rat_stats := stats as RatEnemyStats
		if advance_cycle:
			var rat_seq := rat_stats.pick_art_sequence(_skelton_last_was_long_seq)
			_skelton_last_was_long_seq = RatEnemyStats.is_long_sequence(rat_seq)
			return rat_seq
		return rat_stats.pick_art_sequence()
	return PackedInt32Array()


func _sequence_art_frame_interval(seq: PackedInt32Array) -> float:
	if stats is LittleSkeltonEnemyStats:
		return (stats as LittleSkeltonEnemyStats).frame_interval_for_sequence(seq)
	if stats is CrabEnemyStats:
		return (stats as CrabEnemyStats).frame_interval_for_sequence(seq)
	if stats is RatEnemyStats:
		return (stats as RatEnemyStats).frame_interval_for_sequence(seq)
	return 0.5


func _apply_sequence_art_frame() -> void:
	if _skelton_art_sequence.is_empty() or stats == null:
		return
	var frame_idx: int = _skelton_art_sequence[_skelton_art_seq_step]
	if frame_idx < 0 or frame_idx >= stats.art_frames.size():
		return
	sprite_2d.texture = stats.art_frames[frame_idx]
	if not _hitbox_locked:
		_sync_hitbox_to_sprite()
		_update_arrow_from_hitbox()


func _start_sequence_art_animation() -> void:
	if not _uses_sequence_art():
		return
	_ensure_art_anim_timer()
	_art_anim_timer.wait_time = _sequence_art_frame_interval(_skelton_art_sequence)
	if not _art_anim_timer.is_stopped():
		_art_anim_timer.stop()
	_art_anim_timer.start()


func _advance_sequence_art() -> void:
	_skelton_art_seq_step += 1
	if _skelton_art_seq_step >= _skelton_art_sequence.size():
		_skelton_art_sequence = _pick_sequence_art(true)
		_skelton_art_seq_step = 0
	_apply_sequence_art_frame()
	_art_anim_timer.wait_time = _sequence_art_frame_interval(_skelton_art_sequence)


func _ensure_art_anim_timer() -> void:
	if _art_anim_timer:
		return
	_art_anim_timer = Timer.new()
	_art_anim_timer.one_shot = false
	_art_anim_timer.timeout.connect(_on_art_anim_timer_timeout)
	add_child(_art_anim_timer)


func _start_art_animation() -> void:
	if _uses_sequence_art():
		_start_sequence_art_animation()
		return
	if stats == null or stats.art_frames.size() < 2:
		return
	_ensure_art_anim_timer()
	_art_anim_timer.wait_time = stats.art_frame_interval
	if not _art_anim_timer.is_stopped():
		_art_anim_timer.stop()
	_art_anim_timer.start()


func _stop_art_animation() -> void:
	if _art_anim_timer and not _art_anim_timer.is_stopped():
		_art_anim_timer.stop()


func _on_art_anim_timer_timeout() -> void:
	if _uses_sequence_art():
		_advance_sequence_art()
		return
	if stats == null or stats.art_frames.size() < 2:
		return
	_art_frame_index = (_art_frame_index + 1) % stats.art_frames.size()
	sprite_2d.texture = stats.art_frames[_art_frame_index]
	if not _hitbox_locked:
		_sync_hitbox_to_sprite()
		_update_arrow_from_hitbox()


func _exit_tree() -> void:
	if (
		not Engine.is_editor_hint()
		and Events.enemy_action_completed.is_connected(_on_own_action_completed_restore_position)
	):
		Events.enemy_action_completed.disconnect(_on_own_action_completed_restore_position)
	_editor_unbind_stats_preview_listener()
	_stop_art_animation()
	_clear_interaction_visuals_immediate()
	set_process(false)
	_hide_intent_hover_tooltip_if_active()
