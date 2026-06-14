class_name ShellMechEnemyVisual
extends Node2D

enum VisualState { OPEN, CLOSED, TRANSITIONING }

const FRAME_OPEN := preload("res://art/shell_mech1.png")
const FRAME_MID := preload("res://art/shell_mech2.png")
const FRAME_CLOSED := preload("res://art/shell_mech3.png")
const TRANSITION_SEC := 0.2
const BOB_RANGE_PX := 8.0
const BOB_SEGMENT_SEC := 0.85

var _enemy: Enemy
var _sprite: Sprite2D
var _visual_state := VisualState.OPEN
var _bob_tween: Tween
var _transition_tween: Tween
var _player_turn_count := 0


static func attach_to(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return
	var sprite_2d := enemy.get_node_or_null("Sprite2D") as Sprite2D
	if not is_instance_valid(sprite_2d):
		return
	var existing := enemy.get_node_or_null("ShellMechVisualRig") as ShellMechEnemyVisual
	if existing != null:
		return
	var rig := ShellMechEnemyVisual.new()
	rig.name = "ShellMechVisualRig"
	enemy.add_child(rig)
	enemy.move_child(rig, 0)
	rig.call_deferred("_build", enemy, sprite_2d)


func _build(enemy: Node, sprite_2d: Sprite2D) -> void:
	if not is_instance_valid(enemy) or not is_instance_valid(sprite_2d):
		return
	_enemy = enemy as Enemy
	_sprite = sprite_2d
	_sprite.reparent(self)
	_sprite.position = Vector2.ZERO
	_sprite.texture = FRAME_OPEN
	_visual_state = VisualState.OPEN
	_connect_signals()
	_connect_hard_shell_signal()
	_start_bob()


func _connect_signals() -> void:
	if not Events.player_turn_ended.is_connected(_on_player_turn_ended):
		Events.player_turn_ended.connect(_on_player_turn_ended)
	if not Events.player_turn_intent_context_ready.is_connected(_on_player_turn_intent_context_ready):
		Events.player_turn_intent_context_ready.connect(_on_player_turn_intent_context_ready)
	if not Events.combat_flow_reset.is_connected(_on_combat_flow_reset):
		Events.combat_flow_reset.connect(_on_combat_flow_reset)


func _connect_hard_shell_signal() -> void:
	var hard_shell := HardShellStatus.get_on_enemy(_enemy)
	if hard_shell == null:
		return
	if not hard_shell.shell_spent.is_connected(_on_hard_shell_spent):
		hard_shell.shell_spent.connect(_on_hard_shell_spent)


func _exit_tree() -> void:
	_stop_bob()
	_kill_transition_tween()
	if Events.player_turn_ended.is_connected(_on_player_turn_ended):
		Events.player_turn_ended.disconnect(_on_player_turn_ended)
	if Events.player_turn_intent_context_ready.is_connected(_on_player_turn_intent_context_ready):
		Events.player_turn_intent_context_ready.disconnect(_on_player_turn_intent_context_ready)
	if Events.combat_flow_reset.is_connected(_on_combat_flow_reset):
		Events.combat_flow_reset.disconnect(_on_combat_flow_reset)
	if is_instance_valid(_enemy):
		var hard_shell := HardShellStatus.get_on_enemy(_enemy)
		if hard_shell != null and hard_shell.shell_spent.is_connected(_on_hard_shell_spent):
			hard_shell.shell_spent.disconnect(_on_hard_shell_spent)


func _on_combat_flow_reset() -> void:
	_stop_bob()
	_kill_transition_tween()
	_visual_state = VisualState.OPEN
	if is_instance_valid(_sprite):
		_sprite.texture = FRAME_OPEN


func _on_player_turn_ended() -> void:
	if not is_instance_valid(_enemy) or not is_instance_valid(_sprite):
		return
	play_close_animation()


func _on_player_turn_intent_context_ready() -> void:
	if not is_instance_valid(_enemy) or not is_instance_valid(_sprite):
		return
	_player_turn_count += 1
	if _player_turn_count <= 1:
		return
	play_open_animation()


func _on_hard_shell_spent(host: Enemy) -> void:
	if host != _enemy:
		return
	play_close_animation()


func play_close_animation() -> void:
	if _visual_state != VisualState.OPEN:
		return
	_play_transition(FRAME_OPEN, FRAME_MID, FRAME_CLOSED, VisualState.CLOSED)


func play_open_animation() -> void:
	if _visual_state != VisualState.CLOSED:
		return
	_play_transition(FRAME_CLOSED, FRAME_MID, FRAME_OPEN, VisualState.OPEN)


func _play_transition(from_tex: Texture2D, mid_tex: Texture2D, to_tex: Texture2D, end_state: VisualState) -> void:
	if not is_instance_valid(_sprite):
		return
	_stop_bob()
	_kill_transition_tween()
	_visual_state = VisualState.TRANSITIONING
	_sprite.texture = from_tex
	_transition_tween = create_tween()
	_transition_tween.tween_callback(func() -> void:
		if is_instance_valid(_sprite):
			_sprite.texture = mid_tex
	)
	_transition_tween.tween_interval(TRANSITION_SEC)
	_transition_tween.tween_callback(func() -> void:
		if is_instance_valid(_sprite):
			_sprite.texture = to_tex
	)
	_transition_tween.tween_interval(TRANSITION_SEC)
	_transition_tween.finished.connect(func() -> void:
		_visual_state = end_state
		if end_state == VisualState.OPEN:
			_start_bob()
	, CONNECT_ONE_SHOT)


func _start_bob() -> void:
	if _visual_state != VisualState.OPEN or not is_inside_tree():
		return
	_queue_bob_leg()


func _stop_bob() -> void:
	if _bob_tween != null and _bob_tween.is_valid():
		_bob_tween.kill()
	_bob_tween = null


func _queue_bob_leg() -> void:
	if _visual_state != VisualState.OPEN or not is_inside_tree():
		return
	var target_y := RNG.instance.randf_range(-BOB_RANGE_PX, BOB_RANGE_PX)
	if absf(target_y - position.y) < 2.0:
		target_y = clampf(position.y + BOB_RANGE_PX * 0.5, -BOB_RANGE_PX, BOB_RANGE_PX)
	_stop_bob()
	_bob_tween = create_tween()
	_bob_tween.set_trans(Tween.TRANS_SINE)
	_bob_tween.set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(self, "position:y", target_y, BOB_SEGMENT_SEC)
	_bob_tween.finished.connect(_queue_bob_leg)


func _kill_transition_tween() -> void:
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = null
