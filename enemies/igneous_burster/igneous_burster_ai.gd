class_name IgneousBursterAI
extends EnemyActionPicker

const VOLATILE := preload("res://statuses/unstable.tres")

var _phase: int = 0
var _volatile_spawned: bool = false
var _explode_pulse_tween: Tween


func _ready() -> void:
	super._ready()
	if not Events.enemy_action_completed.is_connected(_on_enemy_action_completed):
		Events.enemy_action_completed.connect(_on_enemy_action_completed)


func _exit_tree() -> void:
	stop_explode_pulse()
	if Events.enemy_action_completed.is_connected(_on_enemy_action_completed):
		Events.enemy_action_completed.disconnect(_on_enemy_action_completed)


func _set_enemy(value: Enemy) -> void:
	super._set_enemy(value)
	if value and not _volatile_spawned:
		_volatile_spawned = true
		call_deferred("_spawn_volatile_status")


func _spawn_volatile_status() -> void:
	if not is_instance_valid(enemy) or not enemy.status_handler:
		return
	if enemy.status_handler.get_status_by_id("igneous_volatile") != null:
		return
	var s := VOLATILE.duplicate()
	s.stacks = 3
	enemy.status_handler.add_status(s)


func _on_enemy_action_completed(e: Enemy) -> void:
	if not is_instance_valid(enemy) or e != enemy:
		return
	var st := enemy.status_handler.get_status_by_id("igneous_volatile") if enemy.status_handler else null
	if st != null and st.stacks > 0:
		st.stacks -= 1


func notify_igneous_strike_done() -> void:
	if _phase < 2:
		_phase += 1
	if _phase == 2:
		call_deferred("start_explode_pulse_loop")


## 爆炸回合（玩家行动期间）：亮度渐亮→渐暗循环，直到 `stop_explode_pulse`。
func start_explode_pulse_loop() -> void:
	if not is_instance_valid(enemy):
		return
	var spr := enemy.sprite_2d
	if spr == null:
		return
	stop_explode_pulse()
	var bright := Color(1.55, 1.32, 1.1, 1.0)
	_explode_pulse_tween = create_tween()
	_explode_pulse_tween.set_loops(0)
	_explode_pulse_tween.set_trans(Tween.TRANS_SINE)
	_explode_pulse_tween.set_ease(Tween.EASE_IN_OUT)
	_explode_pulse_tween.tween_property(spr, "modulate", bright, 0.52)
	_explode_pulse_tween.tween_property(spr, "modulate", Color.WHITE, 0.52)


func stop_explode_pulse() -> void:
	if _explode_pulse_tween != null and _explode_pulse_tween.is_valid():
		_explode_pulse_tween.kill()
	_explode_pulse_tween = null
	if is_instance_valid(enemy) and enemy.sprite_2d:
		enemy.sprite_2d.modulate = Color.WHITE


func get_action() -> EnemyAction:
	match _phase:
		0, 1:
			return $Strike5 as EnemyAction
		2:
			return $Explode as EnemyAction
	return $Strike5 as EnemyAction


func get_first_conditional_action() -> EnemyAction:
	return null
