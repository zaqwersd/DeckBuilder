class_name Player
extends Node2D

const WHITE_SPRITE_MATERIAL := preload("res://art/white_sprite_material.tres")
const HEAL_FLOAT_COLOR := Color(0.35, 1.0, 0.5, 1.0)

@export var stats: CharacterStats : set = set_character_stats

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var stats_ui: StatusBar = $StatusBar
@onready var status_handler: StatusHandler = $StatusBar/StatusHandler
@onready var modifier_handler: ModifierHandler = $ModifierHandler


func _ready() -> void:
	status_handler.status_owner = self
	stats_ui.resized.connect(_schedule_layout_status_bar)
	if is_instance_valid(stats):
		_connect_stats_combat_signals(stats)
	call_deferred("_layout_status_bar")


func _schedule_layout_status_bar() -> void:
	call_deferred("_layout_status_bar")


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

	sprite_2d.texture = stats.art
	update_stats()


func update_stats() -> void:
	stats_ui.update_stats(stats)
	_layout_status_bar()


func take_damage(damage: int, which_modifier: Modifier.Type, use_tween_delay: bool = true) -> void:
	if stats.health <= 0:
		return
	
	sprite_2d.material = WHITE_SPRITE_MATERIAL
	var modified_damage := modifier_handler.get_modified_value(damage, which_modifier)
	
	if not use_tween_delay:
		Shaker.shake(self, 72, 0.15)
		stats.take_damage(modified_damage)
		sprite_2d.material = null
		if stats.health <= 0:
			Events.player_died.emit()
			queue_free()
		return
	
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
				Events.player_died.emit()
				queue_free()
	)


## 与意图数字一致：已按 `player.modifier_handler` + `enemy.modifier_handler` 链式算好的最终伤害，不再二次修饰。
func take_damage_final(final_damage: int, use_tween_delay: bool = true) -> void:
	if stats.health <= 0:
		return
	sprite_2d.material = WHITE_SPRITE_MATERIAL
	if not use_tween_delay:
		Shaker.shake(self, 72, 0.15)
		stats.take_damage(final_damage)
		sprite_2d.material = null
		if stats.health <= 0:
			Events.player_died.emit()
			queue_free()
		return
	var tween := create_tween()
	tween.tween_callback(Shaker.shake.bind(self, 72, 0.15))
	tween.tween_callback(stats.take_damage.bind(final_damage))
	tween.tween_interval(0.17)
	tween.finished.connect(
		func():
			if not is_instance_valid(self):
				return
			sprite_2d.material = null
			if stats.health <= 0:
				Events.player_died.emit()
				queue_free()
	)
