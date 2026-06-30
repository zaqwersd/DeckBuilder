extends Enemy

const FLOAT_AMPLITUDE := 10.0
const FLOAT_DURATION := 1.35
const FLOAT_CYCLE_SEC := FLOAT_DURATION * 2.0

var _float_home := Vector2.ZERO
var _float_tween: Tween
var _float_anim_phase := 0.0


func start_floating_motion() -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	_resolve_battle_sprite_2d()
	if not is_instance_valid(sprite_2d):
		return
	_float_home = sprite_2d.position
	if _float_tween != null and _float_tween.is_valid():
		_float_tween.kill()
	var start_phase := RNG.instance.randf()
	_apply_float_anim_phase(start_phase)
	_float_tween = create_tween().set_loops()
	_float_tween.tween_method(_apply_float_anim_phase, start_phase, start_phase + 1.0, FLOAT_CYCLE_SEC)


func _apply_float_anim_phase(phase: float) -> void:
	_float_anim_phase = phase
	if not is_instance_valid(sprite_2d):
		return
	var norm := fposmod(phase, 1.0)
	var y := _float_home.y - cos(norm * TAU) * FLOAT_AMPLITUDE
	_set_float_sprite_y(y)


func _set_float_sprite_y(y: float) -> void:
	if not is_instance_valid(sprite_2d):
		return
	sprite_2d.position.y = y
	_sync_hitbox_to_sprite()


func _exit_tree() -> void:
	if _float_tween != null and _float_tween.is_valid():
		_float_tween.kill()
	_float_tween = null
	if is_instance_valid(sprite_2d):
		sprite_2d.position = _float_home
		_sync_hitbox_to_sprite()
	super._exit_tree()
