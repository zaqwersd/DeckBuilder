@tool
class_name BladeVisual
extends Node2D

## 部件 PNG 画布尺寸；`Anchor` 偏移 `-CANVAS_SIZE / 2` 等价于单张 `Sprite2D.centered = true`。
const CANVAS_SIZE := Vector2(128, 192)
const DISPLAY_OFFSET_NODE := "DisplayOffset"
const ANCHOR_NODE := "Anchor"
const MARKERS_NODE := "Markers"
const MARKER_WAIST := "挂点_腰部"
const MARKER_HEAD := "挂点_头部"
const MARKER_L_ARM := "挂点_左臂"
const MARKER_R_ARM := "挂点_右臂"
const MARKER_THROW_HAND := "挂点_左手投掷"
const BODY_BREATH_NODE := "BodyBreath"
const RIGHT_ARM_PIVOT := "RightArm"
const RIGHT_ARM_SWING := "ArmPivot"
const LEFT_ARM_PIVOT := "LeftArm"
const LEFT_ARM_SWING := "ArmPivot"

const HEAD_FRAME_1 := preload("res://art/blade/blade_head1.png")
const HEAD_FRAME_2 := preload("res://art/blade/blade_head2.png")
const HEAD_FRAME_3 := preload("res://art/blade/blade_head3.png")

const BLINK_WAIT_MIN_SEC := 2.0
const BLINK_WAIT_MAX_SEC := 5.0
const BREATH_SCALE_MIN := 1.0
const BREATH_SCALE_MAX := 1.04
const BREATH_HALF_CYCLE_SEC := 1.25
## 呼吸时头/手臂随画布顶边上移的幅度，1=与身体同步。
const FOLLOW_MOTION_STRENGTH := 0.4

const ATTACK_LUNGE_SCREEN_PX := 20.0
const ATTACK_LUNGE_HALF_SEC := 0.5
const ATTACK_ARM_HALF_SEC := 0.32
const ATTACK_ARM_ROT := deg_to_rad(-135.0)

const POTION_THROW_PEAK_ROT := deg_to_rad(-180.0)
const POTION_THROW_RELEASE_ROT := deg_to_rad(-90.0)
const POTION_THROW_RETURN_SEC := 0.1
const POTION_SELF_WIND_UP_SEC := 0.1
const POTION_SELF_RETURN_SEC := 0.1
const POTION_SELF_FLIGHT_SEC := 0.2
const POTION_SELF_MIN_ARC_PX := 160.0
const POTION_PROJECTILE_SCENE := preload("res://potions/explode_potion_projectile.tscn")

const PART_PIVOTS: Array[String] = [
	"RightLeg",
	"LeftLeg",
	"Body",
	"RightArm",
	"LeftArm",
	"Head",
]

## 各部件贴图左上角在画布坐标中的原始位置；挂点移动时据此保持拼合不变。
const PART_SPRITE_TOP_LEFT: Dictionary = {
	"Head": Vector2(2, 0),
	"LeftArm": Vector2.ZERO,
	"RightArm": Vector2.ZERO,
}

var _part_sprites: Array[Sprite2D] = []
var _anchor: Node2D
var _body_breath: Node2D
var _head_sprite: Sprite2D
var _marker_waist: Marker2D
var _marker_head: Marker2D
var _marker_l_arm: Marker2D
var _marker_r_arm: Marker2D
var _marker_throw_hand: Marker2D
var _blink_timer: Timer
var _breath_tween: Tween
var _attack_tween: Tween
var _throw_tween: Tween
var _syncing_display_offset := false
var _lunge_offset := Vector2.ZERO
var _attack_arm_rotation := 0.0
var _throw_arm_rotation := 0.0

## 仅平移立绘显示，不参与 Player 血条布局（可在编辑器里直接拖 `DisplayOffset` 或改此值）。
@export var display_offset: Vector2 = Vector2(0, -20):
	set(value):
		display_offset = value
		_sync_display_offset_to_node()


func _ready() -> void:
	apply_layout_now()
	set_process(true)
	if Engine.is_editor_hint():
		return
	_head_sprite.texture = HEAD_FRAME_1
	_schedule_blink()
	if is_inside_tree():
		_start_breathing()
	else:
		tree_entered.connect(_start_breathing, CONNECT_ONE_SHOT)


func _process(_delta: float) -> void:
	_sync_display_offset_from_node_in_editor()
	apply_rig_from_markers()


func apply_layout_now() -> void:
	for pivot_name in PART_PIVOTS:
		var pivot := _find_pivot(pivot_name)
		if pivot == null:
			continue
		for child in pivot.get_children():
			if child is Sprite2D:
				child.centered = false
				child.offset = Vector2.ZERO
			elif child is Node2D:
				var nested_sprite := _find_part_sprite(child as Node2D)
				if nested_sprite != null:
					nested_sprite.centered = false
					nested_sprite.offset = Vector2.ZERO
	_resolve_rig_nodes()
	_sync_display_offset_to_node()
	_sync_anchor_offset()
	apply_rig_from_markers()
	_cache_part_sprites()


func _display_offset_node() -> Node2D:
	return get_node_or_null(DISPLAY_OFFSET_NODE) as Node2D


func _sync_display_offset_to_node() -> void:
	if _syncing_display_offset:
		return
	var node := _display_offset_node()
	if node == null:
		return
	_syncing_display_offset = true
	node.position = display_offset + _lunge_offset
	_syncing_display_offset = false


func _sync_display_offset_from_node_in_editor() -> void:
	if not Engine.is_editor_hint() or _syncing_display_offset:
		return
	var node := _display_offset_node()
	if node == null or node.position == display_offset:
		return
	_syncing_display_offset = true
	display_offset = node.position
	_syncing_display_offset = false


func get_layout_display_offset() -> Vector2:
	var node := _display_offset_node()
	if node != null:
		return node.position
	return display_offset


func _resolve_rig_nodes() -> void:
	var display_root := _display_offset_node()
	var markers: Node = null
	if display_root != null:
		_anchor = display_root.get_node_or_null(ANCHOR_NODE) as Node2D
		markers = display_root.get_node_or_null(MARKERS_NODE)
	else:
		_anchor = get_node_or_null(ANCHOR_NODE) as Node2D
		markers = get_node_or_null(MARKERS_NODE)
	if markers != null:
		_marker_waist = markers.get_node_or_null(MARKER_WAIST) as Marker2D
		_marker_head = markers.get_node_or_null(MARKER_HEAD) as Marker2D
		_marker_l_arm = markers.get_node_or_null(MARKER_L_ARM) as Marker2D
		_marker_r_arm = markers.get_node_or_null(MARKER_R_ARM) as Marker2D
	_resolve_throw_hand_marker()
	if _anchor == null:
		return
	_body_breath = _anchor.get_node_or_null(BODY_BREATH_NODE) as Node2D


func _resolve_throw_hand_marker() -> void:
	var left_arm := _find_pivot(LEFT_ARM_PIVOT)
	if left_arm != null:
		_marker_throw_hand = left_arm.find_child(MARKER_THROW_HAND, true, false) as Marker2D
	if _marker_throw_hand == null:
		var display_root := _display_offset_node()
		if display_root != null:
			var markers := display_root.get_node_or_null(MARKERS_NODE)
			if markers != null:
				_marker_throw_hand = markers.get_node_or_null(MARKER_THROW_HAND) as Marker2D


func _sync_anchor_offset() -> void:
	if _anchor == null:
		return
	_anchor.position = -CANVAS_SIZE * 0.5


## 挂点为 BladeVisual 根局部坐标（(0,0) 在角色中心，与 `DisplayOffset` 无关）。
func _marker_canvas_pos(marker: Marker2D) -> Vector2:
	if _anchor == null:
		_resolve_rig_nodes()
	if _anchor == null:
		return marker.position
	var marker_root := _local_transform_to_root(self, marker).origin
	var anchor_root := _local_transform_to_root(self, _anchor).origin
	return marker_root - anchor_root


func _apply_part_sprite_offset(part_name: String, part: Node2D, canvas_pos: Vector2) -> void:
	var sprite_tl: Vector2 = PART_SPRITE_TOP_LEFT.get(part_name, Vector2.ZERO)
	var sprite := _find_part_sprite(part)
	if sprite != null:
		sprite.position = sprite_tl - canvas_pos


func _find_part_sprite(part: Node2D) -> Sprite2D:
	for child in part.get_children():
		if child is Sprite2D:
			return child as Sprite2D
		if child is Node2D:
			var nested := _find_part_sprite(child as Node2D)
			if nested != null:
				return nested
	return null


func apply_rig_from_markers() -> void:
	if _anchor == null or _marker_waist == null:
		_resolve_rig_nodes()
	if _anchor == null or _marker_waist == null or _body_breath == null:
		return

	var waist_pos := _marker_canvas_pos(_marker_waist)
	_body_breath.position = waist_pos

	var body_sprite := _find_pivot("Body")
	if body_sprite != null:
		for child in body_sprite.get_children():
			if child is Sprite2D:
				child.position = -waist_pos

	var breath_shift := waist_pos * (1.0 - _body_breath.scale.y) * FOLLOW_MOTION_STRENGTH

	var head := _find_pivot("Head")
	if head != null and _marker_head != null:
		var head_canvas := _marker_canvas_pos(_marker_head)
		head.position = head_canvas + breath_shift
		_apply_part_sprite_offset("Head", head, head_canvas)

	var left_arm := _find_pivot("LeftArm")
	if left_arm != null and _marker_l_arm != null:
		var arm_canvas := _marker_canvas_pos(_marker_l_arm)
		left_arm.position = arm_canvas + breath_shift
		_apply_part_sprite_offset("LeftArm", left_arm, arm_canvas)
		left_arm.rotation = 0.0
		var arm_swing := left_arm.get_node_or_null(LEFT_ARM_SWING) as Node2D
		if arm_swing != null:
			arm_swing.rotation = _throw_arm_rotation

	var right_arm := _find_pivot("RightArm")
	if right_arm != null and _marker_r_arm != null:
		var arm_canvas := _marker_canvas_pos(_marker_r_arm)
		right_arm.position = arm_canvas + breath_shift
		_apply_part_sprite_offset("RightArm", right_arm, arm_canvas)
		right_arm.rotation = 0.0
		var arm_swing := right_arm.get_node_or_null(RIGHT_ARM_SWING) as Node2D
		if arm_swing != null:
			arm_swing.rotation = _attack_arm_rotation


func _set_head_texture(tex: Texture2D) -> void:
	if is_instance_valid(_head_sprite):
		_head_sprite.texture = tex


func _find_pivot(pivot_name: String) -> Node2D:
	if _anchor == null:
		_resolve_rig_nodes()
	if _anchor == null:
		return get_node_or_null(pivot_name) as Node2D
	var found := _anchor.find_child(pivot_name, true, false)
	return found as Node2D


func _cache_part_sprites() -> void:
	_part_sprites.clear()
	for pivot_name in PART_PIVOTS:
		var pivot := _find_pivot(pivot_name)
		if pivot == null:
			continue
		for child in pivot.get_children():
			if child is Sprite2D:
				_part_sprites.append(child)
				if pivot_name == "Head":
					_head_sprite = child
			elif child is Node2D:
				var nested_sprite := _find_part_sprite(child as Node2D)
				if nested_sprite != null:
					_part_sprites.append(nested_sprite)


func _schedule_blink() -> void:
	if not is_instance_valid(_head_sprite):
		return
	if _blink_timer == null:
		_blink_timer = Timer.new()
		_blink_timer.one_shot = true
		add_child(_blink_timer)
		_blink_timer.timeout.connect(_play_blink_sequence)
	_blink_timer.wait_time = randf_range(BLINK_WAIT_MIN_SEC, BLINK_WAIT_MAX_SEC)
	_blink_timer.start()


func _play_blink_sequence() -> void:
	if not is_instance_valid(_head_sprite):
		return
	var steps: Array[Array] = [
		[HEAD_FRAME_2, 0.02],
		[HEAD_FRAME_3, 0.05],
		[HEAD_FRAME_2, 0.02],
		[HEAD_FRAME_1, 0.02],
	]
	var tween := create_tween()
	for step in steps:
		var tex: Texture2D = step[0] as Texture2D
		var duration: float = step[1] as float
		tween.tween_callback(_set_head_texture.bind(tex))
		tween.tween_interval(duration)
	tween.tween_callback(_schedule_blink)


func _start_breathing() -> void:
	if not is_instance_valid(_body_breath):
		_resolve_rig_nodes()
	if not is_instance_valid(_body_breath):
		return
	if is_instance_valid(_breath_tween):
		_breath_tween.kill()
	_body_breath.scale = Vector2.ONE
	_breath_tween = create_tween()
	_breath_tween.set_loops()
	_breath_tween.set_trans(Tween.TRANS_SINE)
	_breath_tween.set_ease(Tween.EASE_IN_OUT)
	_breath_tween.tween_property(_body_breath, "scale:y", BREATH_SCALE_MAX, BREATH_HALF_CYCLE_SEC)
	_breath_tween.tween_property(_body_breath, "scale:y", BREATH_SCALE_MIN, BREATH_HALF_CYCLE_SEC)


func get_opaque_bounds_local() -> Rect2:
	apply_layout_now()
	var combined := Rect2()
	var has_rect := false
	for sprite in _part_sprites:
		if not is_instance_valid(sprite) or sprite.texture == null:
			continue
		var sprite_rect := Enemy._opaque_bounds_rect_sprite_local(sprite)
		if not sprite_rect.has_area():
			sprite_rect = sprite.get_rect()
		var local_rect := _sprite_rect_in(self, sprite, sprite_rect)
		if not has_rect:
			combined = local_rect
			has_rect = true
		else:
			combined = combined.merge(local_rect)
	return combined if has_rect else Rect2()


func get_combined_rect_local() -> Rect2:
	apply_layout_now()
	var combined := Rect2()
	var has_rect := false
	for sprite in _part_sprites:
		if not is_instance_valid(sprite) or sprite.texture == null:
			continue
		var local_rect := _sprite_rect_in(self, sprite, sprite.get_rect())
		if not has_rect:
			combined = local_rect
			has_rect = true
		else:
			combined = combined.merge(local_rect)
	return combined if has_rect else Rect2(-CANVAS_SIZE * 0.5, CANVAS_SIZE)


func set_flash_material(material: Material) -> void:
	apply_layout_now()
	for sprite in _part_sprites:
		if is_instance_valid(sprite):
			sprite.material = material


func get_throw_hand_global_position() -> Vector2:
	_resolve_rig_nodes()
	if _marker_throw_hand != null:
		if _marker_throw_hand.is_inside_tree():
			return _marker_throw_hand.global_position
		if is_inside_tree():
			return to_global(_marker_throw_hand.position)
	var left_arm := _find_pivot(LEFT_ARM_PIVOT)
	if left_arm != null:
		if left_arm.is_inside_tree():
			return left_arm.global_position
		if is_inside_tree():
			return to_global(left_arm.position)
	return global_position if is_inside_tree() else Vector2.ZERO


func throw_enemy_potion_at(
	enemy: Enemy,
	icon: Texture2D,
	on_land: Callable,
	land_sfx: AudioStream = null,
) -> void:
	if Engine.is_editor_hint() or not is_inside_tree() or not is_instance_valid(enemy) or icon == null:
		if on_land.is_valid():
			on_land.call()
		return
	var tree := get_tree()
	var land_pos := _enemy_land_global(enemy)
	var fly_done := false

	var on_release := func() -> void:
		var release_pos := get_throw_hand_global_position()
		_fly_potion_projectile(
			tree,
			icon,
			land_sfx,
			release_pos,
			land_pos,
			ExplodePotionProjectile.DEFAULT_FLIGHT_DURATION,
			0.0,
			func() -> void:
				if on_land.is_valid():
					on_land.call()
				fly_done = true,
		)

	await _play_potion_throw_with_release(on_release)
	while not fly_done:
		await tree.process_frame


func throw_self_potion_at(target: Node, icon: Texture2D, on_land: Callable = Callable()) -> void:
	if Engine.is_editor_hint() or not is_inside_tree() or not is_instance_valid(target) or icon == null:
		if on_land.is_valid():
			on_land.call()
		return
	var tree := get_tree()
	var land_pos := _target_land_global(target)
	var fly_done := false

	var on_release := func() -> void:
		var release_pos := get_throw_hand_global_position()
		_fly_potion_projectile(
			tree,
			icon,
			null,
			release_pos,
			land_pos,
			POTION_SELF_FLIGHT_SEC,
			POTION_SELF_MIN_ARC_PX,
			func() -> void:
				if on_land.is_valid():
					on_land.call()
				fly_done = true,
		)

	await _play_self_potion_throw_with_release(on_release)
	while not fly_done:
		await tree.process_frame


func _fly_potion_projectile(
	tree: SceneTree,
	icon: Texture2D,
	land_sfx: AudioStream,
	from: Vector2,
	to: Vector2,
	flight_duration: float,
	min_arc_px: float,
	on_done: Callable,
) -> void:
	var parent := _get_projectile_layer(tree)
	if parent == null:
		on_done.call()
		return
	var projectile := POTION_PROJECTILE_SCENE.instantiate() as ExplodePotionProjectile
	projectile.configure(icon, land_sfx, flight_duration, min_arc_px)
	parent.add_child(projectile)
	await tree.process_frame
	await projectile.fly_to(from, to)
	on_done.call()


func _play_potion_throw_with_release(on_release: Callable) -> void:
	_resolve_rig_nodes()
	if is_instance_valid(_throw_tween):
		if _throw_tween.finished.is_connected(_on_potion_throw_finished):
			_throw_tween.finished.disconnect(_on_potion_throw_finished)
		_throw_tween.kill()
	_apply_throw_arm_rotation(0.0)
	# 瞬移到最高点，再顺时针（角度增大）摆回 0°；半程 (-90°) 抛出药水。
	_apply_throw_arm_rotation(POTION_THROW_PEAK_ROT)
	var return_half := POTION_THROW_RETURN_SEC * 0.5
	_throw_tween = create_tween()
	_throw_tween.set_trans(Tween.TRANS_LINEAR)
	_throw_tween.tween_method(
		_apply_throw_arm_rotation,
		POTION_THROW_PEAK_ROT,
		POTION_THROW_RELEASE_ROT,
		return_half,
	)
	_throw_tween.tween_callback(on_release)
	_throw_tween.tween_method(
		_apply_throw_arm_rotation,
		POTION_THROW_RELEASE_ROT,
		0.0,
		return_half,
	)
	_throw_tween.finished.connect(_on_potion_throw_finished, CONNECT_ONE_SHOT)
	await _throw_tween.finished


func _play_self_potion_throw_with_release(on_release: Callable) -> void:
	_resolve_rig_nodes()
	if is_instance_valid(_throw_tween):
		if _throw_tween.finished.is_connected(_on_potion_throw_finished):
			_throw_tween.finished.disconnect(_on_potion_throw_finished)
		_throw_tween.kill()
	_apply_throw_arm_rotation(0.0)
	_throw_tween = create_tween()
	_throw_tween.set_trans(Tween.TRANS_LINEAR)
	_throw_tween.tween_method(
		_apply_throw_arm_rotation,
		0.0,
		POTION_THROW_PEAK_ROT,
		POTION_SELF_WIND_UP_SEC,
	)
	_throw_tween.tween_callback(on_release)
	_throw_tween.tween_method(
		_apply_throw_arm_rotation,
		POTION_THROW_PEAK_ROT,
		0.0,
		POTION_SELF_RETURN_SEC,
	)
	_throw_tween.finished.connect(_on_potion_throw_finished, CONNECT_ONE_SHOT)
	await _throw_tween.finished


func _target_land_global(target: Node) -> Vector2:
	if target.has_method("_floating_number_anchor_local"):
		var local: Variant = target.call("_floating_number_anchor_local")
		if local is Vector2:
			return target.to_global(local as Vector2)
	return target.global_position


func _enemy_land_global(enemy: Enemy) -> Vector2:
	if enemy.has_method("_floating_number_anchor_local"):
		var local: Variant = enemy.call("_floating_number_anchor_local")
		if local is Vector2:
			return enemy.to_global(local as Vector2)
	return enemy.global_position


func _get_projectile_layer(tree: SceneTree) -> Node:
	var ui_layer := tree.get_first_node_in_group("ui_layer")
	if ui_layer is CanvasLayer:
		return ui_layer as CanvasLayer
	var run := tree.get_first_node_in_group("run") as Run
	if run != null and run.current_view.get_child_count() > 0:
		return run.current_view.get_child(0)
	return tree.current_scene


func _on_potion_throw_finished() -> void:
	_throw_tween = null
	_reset_throw_pose()


func play_attack_lunge() -> void:
	if Engine.is_editor_hint():
		return
	_resolve_rig_nodes()
	var lunge_x := _attack_lunge_local_x()
	if is_instance_valid(_attack_tween):
		_attack_tween.kill()
	_reset_attack_pose()
	_set_attack_arm_rotation(ATTACK_ARM_ROT)
	_attack_tween = create_tween()
	_attack_tween.set_trans(Tween.TRANS_SINE)
	_attack_tween.set_ease(Tween.EASE_IN_OUT)
	_attack_tween.tween_method(_set_lunge_offset, Vector2.ZERO, Vector2(lunge_x, 0.0), ATTACK_LUNGE_HALF_SEC)
	_attack_tween.parallel().tween_method(_set_attack_arm_rotation, ATTACK_ARM_ROT, 0.0, ATTACK_ARM_HALF_SEC)
	_attack_tween.chain().tween_method(_set_lunge_offset, Vector2(lunge_x, 0.0), Vector2.ZERO, ATTACK_LUNGE_HALF_SEC)
	_attack_tween.finished.connect(_on_attack_lunge_finished, CONNECT_ONE_SHOT)


func _on_attack_lunge_finished() -> void:
	_attack_tween = null
	_reset_attack_pose()


func _reset_attack_pose() -> void:
	_lunge_offset = Vector2.ZERO
	_set_attack_arm_rotation(0.0)
	_sync_display_offset_to_node()


func _set_attack_arm_rotation(angle: float) -> void:
	_attack_arm_rotation = angle
	var right_arm := _find_pivot(RIGHT_ARM_PIVOT)
	if right_arm == null:
		return
	right_arm.rotation = 0.0
	var arm_swing := right_arm.get_node_or_null(RIGHT_ARM_SWING) as Node2D
	if arm_swing != null:
		arm_swing.rotation = angle


func _attack_lunge_local_x() -> float:
	var sx := absf(scale.x)
	if sx < 0.001:
		sx = 1.0
	return ATTACK_LUNGE_SCREEN_PX / sx


func _set_lunge_offset(value: Vector2) -> void:
	_lunge_offset = value
	_sync_display_offset_to_node()


func _reset_throw_pose() -> void:
	_apply_throw_arm_rotation(0.0)


func _apply_throw_arm_rotation(angle: float) -> void:
	_throw_arm_rotation = angle
	var left_arm := _find_pivot(LEFT_ARM_PIVOT)
	if left_arm == null:
		return
	left_arm.rotation = 0.0
	var arm_swing := left_arm.get_node_or_null(LEFT_ARM_SWING) as Node2D
	if arm_swing != null:
		arm_swing.rotation = angle


func _sprite_rect_in(root: Node2D, sprite: Sprite2D, rect: Rect2) -> Rect2:
	var xf := _local_transform_to_root(root, sprite)
	var corners := [
		rect.position,
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + Vector2(0.0, rect.size.y),
		rect.position + rect.size,
	]
	var min_p: Vector2 = xf * corners[0]
	var max_p: Vector2 = min_p
	for i in range(1, corners.size()):
		var local_corner: Vector2 = xf * corners[i]
		min_p.x = minf(min_p.x, local_corner.x)
		min_p.y = minf(min_p.y, local_corner.y)
		max_p.x = maxf(max_p.x, local_corner.x)
		max_p.y = maxf(max_p.y, local_corner.y)
	return Rect2(min_p, max_p - min_p)


func _local_transform_to_root(root: Node2D, node: Node2D) -> Transform2D:
	var chain: Array[Node2D] = []
	var current: Node = node
	while current != null and current != root:
		if current is Node2D:
			chain.append(current)
		current = current.get_parent()
	chain.reverse()
	var xf := Transform2D.IDENTITY
	for n in chain:
		xf = xf * n.transform
	return xf
