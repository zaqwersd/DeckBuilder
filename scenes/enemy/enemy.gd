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
## key -> `Rect2i`（贴图像素坐标下的不透明 AABB，size 至少为 1×1）
static var _opaque_texel_aabb_cache: Dictionary = {}

@export var stats: EnemyStats : set = set_enemy_stats

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var arrow: Sprite2D = $Arrow
@onready var stats_ui: StatusBar = $StatusBar
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
## take_damage 调用时若在攻击牌窗口内计数；实际扣血后发出 player_dealt_attack_damage_to_enemy（tween 晚于 end_attack_card_effects）
var _pending_player_attack_card_hits: int = 0


func _ready() -> void:
	status_handler.status_owner = self
	stats_ui.resized.connect(_schedule_layout_status_bar)
	if is_instance_valid(stats):
		_connect_stats_combat_signals(stats)
	call_deferred("_layout_status_bar")
	call_deferred("_deferred_connect_intent_tooltip_handlers")
	set_process(false)


func _schedule_layout_status_bar() -> void:
	call_deferred("_layout_status_bar")


func _deferred_connect_intent_tooltip_handlers() -> void:
	var tree := get_tree()
	if tree:
		IntentUI.ensure_intent_tooltip_handlers_connected(tree)


func _process(_delta: float) -> void:
	if not is_inside_tree():
		return
	if Events.is_combat_ended():
		_hide_intent_hover_tooltip_if_active()
		return
	if not is_instance_valid(stats) or stats.health <= 0:
		_hide_intent_hover_tooltip_if_active()
		return
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


func _hide_intent_hover_tooltip_if_active() -> void:
	if not _intent_hover_tooltip_active:
		return
	_intent_hover_tooltip_active = false
	Events.intent_tooltip_hover_hide.emit()


func _apply_intent_ui_offset() -> void:
	if not is_instance_valid(intent_ui) or stats == null:
		return
	var o := stats.intent_ui_offset
	intent_ui.offset_left = _INTENT_UI_BASE_LEFT + o.x
	intent_ui.offset_right = _INTENT_UI_BASE_RIGHT + o.x
	intent_ui.offset_top = _INTENT_UI_BASE_TOP - o.y
	intent_ui.offset_bottom = _INTENT_UI_BASE_BOTTOM - o.y


func _layout_status_bar() -> void:
	if not is_instance_valid(stats_ui) or not is_instance_valid(sprite_2d) or stats == null:
		return
	var foot_y := _sprite_foot_local_y()
	var off := stats.status_bar_offset
	var w := maxf(stats_ui.size.x, stats_ui.get_combined_minimum_size().x)
	stats_ui.position = Vector2(-w * 0.5 + off.x, foot_y + off.y)


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


func _disconnect_stats_combat_signals(s: Stats) -> void:
	if s == null:
		return
	if s.unblocked_damage_taken.is_connected(_on_stats_unblocked_damage_taken):
		s.unblocked_damage_taken.disconnect(_on_stats_unblocked_damage_taken)
	if s.healing_applied.is_connected(_on_stats_healing_applied):
		s.healing_applied.disconnect(_on_stats_healing_applied)


func _on_stats_unblocked_damage_taken(amount: int) -> void:
	FloatingCombatNumber.spawn(self, _floating_number_anchor_local(), amount, Color.WHITE)
	var heavy_armor := HeavyArmorStatus.get_on_enemy(self)
	if heavy_armor != null and amount > 0:
		heavy_armor.register_damage_taken(amount, self)
	if _pending_player_attack_card_hits > 0:
		_pending_player_attack_card_hits -= 1
		if amount > 0 and not Events.is_combat_ended():
			Events.player_dealt_attack_damage_to_enemy.emit(self, amount)


func _on_stats_healing_applied(amount: int) -> void:
	FloatingCombatNumber.spawn(self, _floating_number_anchor_local(), amount, HEAL_FLOAT_COLOR)


func set_current_action(value: EnemyAction) -> void:
	current_action = value
	update_intent()


func set_enemy_stats(value: EnemyStats) -> void:
	if is_instance_valid(stats):
		_disconnect_stats_combat_signals(stats)
	if not is_instance_valid(value):
		stats = null
		return
	stats = value.create_instance() as EnemyStats
	_connect_stats_combat_signals(stats)
	
	if not stats.stats_changed.is_connected(update_stats):
		stats.stats_changed.connect(update_stats)
		stats.stats_changed.connect(update_action)
	
	update_enemy()


func setup_ai() -> void:
	if enemy_action_picker:
		enemy_action_picker.queue_free()
		
	var new_action_picker := stats.ai.instantiate() as EnemyActionPicker
	add_child(new_action_picker)
	enemy_action_picker = new_action_picker
	enemy_action_picker.enemy = self


func update_stats() -> void:
	stats_ui.update_stats(stats)
	_layout_status_bar()


func update_action() -> void:
	if not enemy_action_picker:
		return
	
	if not current_action:
		current_action = enemy_action_picker.get_action()
		update_intent()
		return
	
	var new_conditional_action := enemy_action_picker.get_first_conditional_action()
	if new_conditional_action and current_action != new_conditional_action:
		current_action = new_conditional_action
		update_intent()


func update_enemy() -> void:
	if not stats is Stats: 
		return
	if not is_inside_tree(): 
		await ready
	
	_apply_enemy_art()
	if stats is EnemyStats:
		sprite_2d.scale = stats.art_scale
	var half_width := sprite_2d.get_rect().size.x * absf(sprite_2d.scale.x) * 0.5
	arrow.position = Vector2.RIGHT * (half_width + ARROW_OFFSET)
	_sync_hitbox_to_sprite()
	setup_ai()
	update_stats()
	_apply_intent_ui_offset()
	call_deferred("_apply_intent_ui_offset")


## 单体牌瞄准依赖与敌人 `Area2D` 的重叠；按贴图 **alpha>阈值** 的实体像素做 AABB，避免整块画布透明边也被当成目标。
func _sync_hitbox_to_sprite() -> void:
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
	var rect_shape := prev.duplicate() as RectangleShape2D
	min_v -= Vector2(HITBOX_PAD_PX, HITBOX_PAD_PX)
	max_v += Vector2(HITBOX_PAD_PX, HITBOX_PAD_PX)
	rect_shape.size = max_v - min_v
	collision_shape_2d.shape = rect_shape
	collision_shape_2d.position = (min_v + max_v) * 0.5
	collision_shape_2d.scale = Vector2.ONE


## `Sprite2D` 局部坐标下用于碰撞的轴对齐矩形（优先不透明像素，否则整张贴图 `get_rect()`）。
func _sprite_local_bounds_for_hitbox() -> Rect2:
	var opaque := _opaque_bounds_rect_sprite_local(sprite_2d)
	if opaque.has_area():
		return opaque
	return sprite_2d.get_rect()


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
	current_action = null
	_apply_intent_ui_hidden()


func _apply_intent_ui_hidden() -> void:
	if is_instance_valid(intent_ui):
		intent_ui.update_intents([])
	set_process(false)
	_hide_intent_hover_tooltip_if_active()


func update_intent() -> void:
	var planned: Array[Intent] = []
	if current_action:
		current_action.update_planned_intents()
		planned = current_action.get_planned_intents()
	intent_ui.update_intents(planned)
	if planned.is_empty():
		set_process(false)
		_hide_intent_hover_tooltip_if_active()
	else:
		set_process(true)


func do_turn() -> void:
	if not is_instance_valid(stats):
		return
	stats.block = 0
	_hide_intent_hover_tooltip_if_active()

	if not current_action:
		return

	if is_instance_valid(intent_ui) and intent_ui.visible and intent_ui.get_child_count() > 0:
		await intent_ui.play_action_start_animation()

	if not is_instance_valid(self) or not is_instance_valid(current_action):
		return

	current_action.perform_action()


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
	if _pending_player_attack_card_hits > 0 and damage <= 0:
		_pending_player_attack_card_hits -= 1
	_apply_damage_to_stats(damage)


func _apply_damage_to_stats(damage: int) -> void:
	if is_instance_valid(stats):
		stats.take_damage(damage)


func take_damage(damage: int, which_modifier: Modifier.Type) -> void:
	if stats.health <= 0:
		return
	
	if (
		which_modifier == Modifier.Type.DMG_TAKEN
		and Events.is_inside_attack_card_effects()
	):
		_pending_player_attack_card_hits += 1
	
	sprite_2d.material = WHITE_SPRITE_MATERIAL
	var modified_damage := modifier_handler.get_modified_value(damage, which_modifier)
	if (
		which_modifier == Modifier.Type.DMG_TAKEN
		and Events.is_inside_attack_card_effects()
	):
		var p := get_tree().get_first_node_in_group("battle_player") as Player
		if p:
			modified_damage = OverwhelmingStatus.apply_multiplier_to_final_attack_damage(p, modified_damage)
	
	var damage_to_apply := modified_damage
	var heavy_armor := HeavyArmorStatus.get_on_enemy(self)
	if heavy_armor != null:
		damage_to_apply = heavy_armor.clamp_incoming_damage(modified_damage, stats.block)
	
	var tween := create_tween()
	tween.tween_callback(Shaker.shake.bind(self, 72, 0.15))
	tween.tween_callback(_apply_damage_tween.bind(damage_to_apply))
	tween.tween_interval(0.17)

	tween.finished.connect(
		func():
			if not is_instance_valid(self):
				return
			sprite_2d.material = null
			
			if stats.health <= 0:
				Events.enemy_died.emit(self)
				queue_free()
	)


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
	_sync_hitbox_to_sprite()
	var half_width := sprite_2d.get_rect().size.x * absf(sprite_2d.scale.x) * 0.5
	arrow.position = Vector2.RIGHT * (half_width + ARROW_OFFSET)


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
	_sync_hitbox_to_sprite()
	var half_width := sprite_2d.get_rect().size.x * absf(sprite_2d.scale.x) * 0.5
	arrow.position = Vector2.RIGHT * (half_width + ARROW_OFFSET)


func _exit_tree() -> void:
	_stop_art_animation()
	set_process(false)
	_hide_intent_hover_tooltip_if_active()


func _on_area_entered(_area: Area2D) -> void:
	arrow.show()


func _on_area_exited(_area: Area2D) -> void:
	arrow.hide()
