class_name Player
extends Node2D

const WHITE_SPRITE_MATERIAL := preload("res://art/white_sprite_material.tres")
const HEAL_FLOAT_COLOR := Color(0.35, 1.0, 0.5, 1.0)

@export var stats: CharacterStats : set = set_character_stats

@onready var _art_root: Node2D = $ArtRoot
@onready var _legacy_sprite: Sprite2D = $ArtRoot/Sprite2D
@onready var stats_ui: StatusBar = $StatusBar
@onready var hover_name_overlay: Label = $HoverNameOverlay
@onready var status_handler: StatusHandler = $StatusBar/StatusHandler
@onready var modifier_handler: ModifierHandler = $ModifierHandler

var _art_instance: Node2D
var _pending_damage_dealer: Enemy
var _lethal_death_pending := false
var _pointer_hover := false


func set_pending_damage_dealer(dealer: Enemy) -> void:
	_pending_damage_dealer = dealer


func clear_pending_damage_dealer() -> void:
	_pending_damage_dealer = null


func _ready() -> void:
	status_handler.status_owner = self
	stats_ui.resized.connect(_schedule_layout_status_bar)
	if is_instance_valid(hover_name_overlay):
		hover_name_overlay.hide_immediate()
	if is_instance_valid(stats):
		_connect_stats_combat_signals(stats)
	if not Events.player_attack_hit_enemy.is_connected(_on_player_attack_hit_enemy):
		Events.player_attack_hit_enemy.connect(_on_player_attack_hit_enemy)
	call_deferred("_layout_status_bar")
	if is_instance_valid(stats):
		call_deferred("_finish_update_player")
	set_process(false)


func _ensure_art_nodes() -> bool:
	if not is_instance_valid(_art_root):
		_art_root = get_node_or_null("ArtRoot") as Node2D
	if not is_instance_valid(_legacy_sprite) and is_instance_valid(_art_root):
		_legacy_sprite = _art_root.get_node_or_null("Sprite2D") as Sprite2D
	return is_instance_valid(_art_root) and is_instance_valid(_legacy_sprite)


func _exit_tree() -> void:
	set_process(false)
	if Events.player_attack_hit_enemy.is_connected(_on_player_attack_hit_enemy):
		Events.player_attack_hit_enemy.disconnect(_on_player_attack_hit_enemy)
	if is_instance_valid(hover_name_overlay):
		hover_name_overlay.hide_immediate()


func _process(_delta: float) -> void:
	if not is_inside_tree():
		return
	if Events.is_combat_ended():
		_update_pointer_hover_state()
		return
	if stats == null or stats.health <= 0 or _lethal_death_pending:
		_update_pointer_hover_state()
		return
	_update_pointer_hover_state()


func get_blade_visual() -> BladeVisual:
	if _art_instance is BladeVisual:
		return _art_instance as BladeVisual
	return null


func _uses_scene_art() -> bool:
	return is_instance_valid(_art_instance)


func _get_art_node() -> Node2D:
	if _uses_scene_art():
		return _art_instance
	return _legacy_sprite


func _get_art_bounds_local() -> Rect2:
	if _uses_scene_art():
		if _art_instance is BladeVisual:
			return (_art_instance as BladeVisual).get_opaque_bounds_local()
		if _art_instance.has_method("get_opaque_bounds_local"):
			var opaque: Variant = _art_instance.call("get_opaque_bounds_local")
			if opaque is Rect2 and (opaque as Rect2).has_area():
				return opaque
	if is_instance_valid(_legacy_sprite) and _legacy_sprite.visible and _legacy_sprite.texture != null:
		var opaque := Enemy._opaque_bounds_rect_sprite_local(_legacy_sprite)
		if opaque.has_area():
			return opaque
		return _legacy_sprite.get_rect()
	return Rect2()


## 与旧版 `sprite_2d.get_rect()` 一致，用于血条/飘字（不含 scale）。
func _get_art_layout_rect_local() -> Rect2:
	if _uses_scene_art():
		if _art_instance is BladeVisual:
			return (_art_instance as BladeVisual).get_combined_rect_local()
		if _art_instance.has_method("get_combined_rect_local"):
			var rect: Variant = _art_instance.call("get_combined_rect_local")
			if rect is Rect2:
				return rect
	if is_instance_valid(_legacy_sprite) and _legacy_sprite.texture != null:
		return _legacy_sprite.get_rect()
	return Rect2()


func _set_art_flash_material(material: Material) -> void:
	if _uses_scene_art() and _art_instance is BladeVisual:
		(_art_instance as BladeVisual).set_flash_material(material)
	elif is_instance_valid(_legacy_sprite):
		_legacy_sprite.material = material


func _clear_art_instance() -> void:
	if is_instance_valid(_art_instance):
		_art_instance.queue_free()
	_art_instance = null


func _art_visual_offset() -> Vector2:
	if not _uses_scene_art():
		return Vector2.ZERO
	if _art_instance is BladeVisual:
		return (_art_instance as BladeVisual).get_layout_display_offset()
	if stats is CharacterStats:
		return (stats as CharacterStats).art_scene_offset
	return Vector2.ZERO


func _apply_art_visual() -> void:
	if not stats is CharacterStats or not _ensure_art_nodes():
		return
	_clear_art_instance()
	var art_scene := stats.get_art_scene()
	if art_scene == null:
		_legacy_sprite.visible = true
		_legacy_sprite.texture = stats.art
		if stats is CharacterStats:
			_legacy_sprite.position = (stats as CharacterStats).art_scene_offset
		_layout_status_bar()
		return
	_legacy_sprite.visible = false
	_art_instance = art_scene.instantiate() as Node2D
	_art_root.add_child(_art_instance)
	if stats is CharacterStats and not (_art_instance is BladeVisual):
		_art_instance.position = (stats as CharacterStats).art_scene_offset
	if _art_instance.has_method("apply_layout_now"):
		_art_instance.call("apply_layout_now")
	_layout_status_bar()


func _art_layout_origin() -> Vector2:
	var art_node := _get_art_node()
	if not is_instance_valid(art_node):
		return Vector2.ZERO
	var root := _art_root if is_instance_valid(_art_root) else self
	return root.position + art_node.position


func _pointer_over_sprite() -> bool:
	var bounds := _get_art_bounds_local()
	if bounds.size == Vector2.ZERO:
		return false
	var art_node := _get_art_node()
	if not is_instance_valid(art_node):
		return false
	var local_point := art_node.to_local(get_global_mouse_position())
	return bounds.has_point(local_point)


func _pointer_over_status_ui(screen_global: Vector2) -> bool:
	return CombatPointer.control_has_screen_point(stats_ui, screen_global)


func _update_pointer_hover_state() -> void:
	var over := false
	if is_instance_valid(stats) and stats.health > 0 and not _lethal_death_pending and not Events.is_combat_ended():
		var viewport := get_viewport()
		var screen_pos := CombatPointer.screen_mouse(viewport)
		over = _pointer_over_sprite() or _pointer_over_status_ui(screen_pos)
		if over and is_instance_valid(stats_ui) and Events.is_pointer_ui_obscured_for(stats_ui):
			over = false
	if over == _pointer_hover:
		return
	_pointer_hover = over
	_refresh_hover_name_visual()


func _player_has_display_name() -> bool:
	return stats is CharacterStats and not (stats as CharacterStats).get_display_name().is_empty()


func _sync_combatant_hover_name_text() -> void:
	if not is_instance_valid(hover_name_overlay) or stats == null:
		return
	hover_name_overlay.set_display_name((stats as CharacterStats).get_display_name())


func _refresh_hover_name_visual() -> void:
	if not is_instance_valid(hover_name_overlay):
		return
	var show_name := _pointer_hover and _player_has_display_name()
	hover_name_overlay.tween_visibility(1.0 if show_name else 0.0)


func _sync_combat_process_enabled() -> void:
	if not is_inside_tree() or stats == null or stats.health <= 0 or _lethal_death_pending:
		set_process(false)
		return
	if Events.is_combat_ended():
		set_process(false)
		return
	set_process(true)


func _schedule_layout_status_bar() -> void:
	call_deferred("_layout_status_bar")


func _layout_status_bar() -> void:
	if not is_instance_valid(stats_ui) or not is_instance_valid(_art_root) or stats == null:
		return
	var foot_y := _sprite_foot_local_y()
	var off := stats.status_bar_offset
	var w := maxf(stats_ui.size.x, stats_ui.get_combined_minimum_size().x)
	stats_ui.position = Vector2(-w * 0.5 + off.x, foot_y + off.y)
	if is_instance_valid(hover_name_overlay):
		hover_name_overlay.z_as_relative = true
		hover_name_overlay.z_index = CombatantHoverName.DRAW_Z_INDEX
		move_child(hover_name_overlay, get_child_count() - 1)
		hover_name_overlay.call_deferred("sync_layout_from_status_bar", stats_ui)


func _sprite_foot_local_y() -> float:
	var rect := _get_art_layout_rect_local()
	if not rect.has_area():
		return 40.0
	var origin := _art_layout_origin()
	return origin.y + rect.position.y + rect.size.y - _art_visual_offset().y


func _floating_number_anchor_local() -> Vector2:
	var rect := _get_art_layout_rect_local()
	if not rect.has_area():
		return Vector2(0, -48)
	var origin := _art_layout_origin()
	var cx := origin.x + rect.get_center().x
	var top := origin.y + rect.position.y
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
	if amount > 0 and is_instance_valid(_pending_damage_dealer) and not Events.is_combat_ended():
		Events.enemy_dealt_unblocked_damage_to_player.emit(_pending_damage_dealer, amount)


func _on_stats_healing_applied(amount: int) -> void:
	FloatingCombatNumber.spawn(self, _floating_number_anchor_local(), amount, HEAL_FLOAT_COLOR)


func _on_player_attack_hit_enemy(_enemy: Enemy, _amount: int) -> void:
	if _art_instance is BladeVisual:
		(_art_instance as BladeVisual).play_attack_lunge()


func set_character_stats(value: CharacterStats) -> void:
	if is_instance_valid(stats):
		_disconnect_stats_combat_signals(stats)
	stats = value
	_connect_stats_combat_signals(stats)
	
	if not stats.stats_changed.is_connected(update_stats):
		stats.stats_changed.connect(update_stats)

	update_player()


func update_player() -> void:
	if not stats is CharacterStats: 
		return
	if not is_inside_tree(): 
		await ready

	call_deferred("_finish_update_player")


func _finish_update_player() -> void:
	if not stats is CharacterStats:
		return
	_apply_art_visual()
	_sync_combatant_hover_name_text()
	update_stats()
	_sync_combat_process_enabled()


func update_stats() -> void:
	stats_ui.update_stats(stats)
	_layout_status_bar()
	_sync_combat_process_enabled()


func handle_lethal_if_needed() -> bool:
	if stats == null or stats.health > 0:
		return false
	var tree := get_tree()
	if tree == null:
		return false
	var run := tree.get_first_node_in_group("run") as Run
	if run == null or not is_instance_valid(run.relic_handler):
		return false
	return run.relic_handler.try_prevent_player_lethal(self)


func _die_from_lethal() -> void:
	if is_instance_valid(hover_name_overlay):
		hover_name_overlay.hide_immediate()
	set_process(false)
	Events.player_died.emit()
	queue_free()


func _play_damage_shake() -> void:
	if not is_instance_valid(self) or _lethal_death_pending:
		return
	Shaker.shake(self, 72, 0.15)


func _on_take_damage_tween_finished() -> void:
	if not is_instance_valid(self) or _lethal_death_pending:
		return
	_set_art_flash_material(null)
	if stats.health <= 0:
		if handle_lethal_if_needed():
			return
		_lethal_death_pending = true
		_die_from_lethal()


func _apply_damage_to_stats(amount: int) -> void:
	if not is_instance_valid(self) or _lethal_death_pending or stats.health <= 0:
		return
	stats.take_damage(amount)
	clear_pending_damage_dealer()


func take_damage(damage: int, which_modifier: Modifier.Type, use_tween_delay: bool = true) -> void:
	if stats.health <= 0 or _lethal_death_pending:
		return
	
	_set_art_flash_material(WHITE_SPRITE_MATERIAL)
	var modified_damage := modifier_handler.get_modified_value(damage, which_modifier)
	
	if not use_tween_delay:
		Shaker.shake(self, 72, 0.15)
		_apply_damage_to_stats(modified_damage)
		_set_art_flash_material(null)
		if stats.health <= 0:
			if handle_lethal_if_needed():
				return
			_lethal_death_pending = true
			_die_from_lethal()
		return
	
	var tween := create_tween()
	tween.tween_callback(_play_damage_shake)
	tween.tween_callback(_apply_damage_to_stats.bind(modified_damage))
	tween.tween_interval(0.17)
	tween.finished.connect(_on_take_damage_tween_finished, CONNECT_ONE_SHOT)


## 与意图数字一致：已按 `player.modifier_handler` + `enemy.modifier_handler` 链式算好的最终伤害，不再二次修饰。
func take_damage_final(final_damage: int, use_tween_delay: bool = true) -> void:
	if stats.health <= 0 or _lethal_death_pending:
		return
	_set_art_flash_material(WHITE_SPRITE_MATERIAL)
	if not use_tween_delay:
		Shaker.shake(self, 72, 0.15)
		_apply_damage_to_stats(final_damage)
		_set_art_flash_material(null)
		if stats.health <= 0:
			if handle_lethal_if_needed():
				return
			_lethal_death_pending = true
			_die_from_lethal()
		return
	var tween := create_tween()
	tween.tween_callback(_play_damage_shake)
	tween.tween_callback(_apply_damage_to_stats.bind(final_damage))
	tween.tween_interval(0.17)
	tween.finished.connect(_on_take_damage_tween_finished, CONNECT_ONE_SHOT)
