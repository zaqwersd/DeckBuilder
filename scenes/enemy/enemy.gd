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
	var gp := get_global_mouse_position()
	var over := _pointer_over_enemy_body(gp) or _pointer_over_intent_ui(gp)
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
	if not intent_ui.visible:
		return false
	return intent_ui.get_global_rect().has_point(screen_global)


func _pointer_over_enemy_body(screen_global: Vector2) -> bool:
	if not is_instance_valid(collision_shape_2d) or collision_shape_2d.shape == null:
		return false
	var rect_shape := collision_shape_2d.shape as RectangleShape2D
	if rect_shape == null:
		return false
	var inv := collision_shape_2d.global_transform.affine_inverse()
	var local_p: Vector2 = inv * screen_global
	return Rect2(-rect_shape.size * 0.5, rect_shape.size).has_point(local_p)


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
		return
	
	var new_conditional_action := enemy_action_picker.get_first_conditional_action()
	if new_conditional_action and current_action != new_conditional_action:
		current_action = new_conditional_action


func update_enemy() -> void:
	if not stats is Stats: 
		return
	if not is_inside_tree(): 
		await ready
	
	sprite_2d.texture = stats.art
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
	print("[DEBUG] Enemy do_turn called on: ", name)
	if not is_instance_valid(stats):
		print("[DEBUG] Early return - stats invalid")
		return
	stats.block = 0

	if not current_action:
		print("[DEBUG] Early return - current_action is null")
		return

	print("[DEBUG] Performing action: ", current_action.name if current_action.name else "unnamed")
	current_action.perform_action()


func take_damage(damage: int, which_modifier: Modifier.Type) -> void:
	if stats.health <= 0:
		return
	
	sprite_2d.material = WHITE_SPRITE_MATERIAL
	var modified_damage := modifier_handler.get_modified_value(damage, which_modifier)
	if (
		which_modifier == Modifier.Type.DMG_TAKEN
		and Events.is_inside_attack_card_effects()
	):
		var p := get_tree().get_first_node_in_group("battle_player") as Player
		if p:
			modified_damage = OverwhelmingStatus.apply_multiplier_to_final_attack_damage(p, modified_damage)
	
	var tween := create_tween()
	tween.tween_callback(Shaker.shake.bind(self, 72, 0.15))
	tween.tween_callback(stats.take_damage.bind(modified_damage))
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


func _exit_tree() -> void:
	set_process(false)
	_hide_intent_hover_tooltip_if_active()


func _on_area_entered(_area: Area2D) -> void:
	arrow.show()


func _on_area_exited(_area: Area2D) -> void:
	arrow.hide()
