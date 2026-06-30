class_name PotionHandler
extends Node

const DEFAULT_SLOTS := 3
const TARGET_PICKER_SCENE := preload("res://scenes/potion_handler/potion_target_picker.tscn")

signal slots_changed

var slots: Array[Potion] = []

var _target_picker: PotionTargetPicker


func _get_active_battle() -> Battle:
	var run := get_tree().get_first_node_in_group("run") as Run
	if run == null or run.current_view.get_child_count() == 0:
		return null
	return run.current_view.get_child(0) as Battle


func _ensure_target_picker() -> void:
	if is_instance_valid(_target_picker):
		return
	var battle := _get_active_battle()
	if battle == null:
		return
	_target_picker = TARGET_PICKER_SCENE.instantiate() as PotionTargetPicker
	battle.add_child(_target_picker)


func _ready() -> void:
	_ensure_default_slots()


func _ensure_default_slots() -> void:
	if slots.is_empty():
		set_slot_count(DEFAULT_SLOTS)


func set_slot_count(count: int) -> void:
	var target := maxi(DEFAULT_SLOTS, count)
	while slots.size() < target:
		slots.append(null)
	while slots.size() > target:
		slots.remove_at(slots.size() - 1)
	slots_changed.emit()


func add_empty_slots(amount: int) -> void:
	if amount <= 0:
		return
	set_slot_count(slots.size() + amount)


func remove_empty_slots_from_end(amount: int) -> void:
	var remaining := amount
	while remaining > 0 and slots.size() > DEFAULT_SLOTS:
		var last := slots.size() - 1
		if slots[last] != null:
			break
		slots.remove_at(last)
		remaining -= 1
	slots_changed.emit()


func has_empty_slot() -> bool:
	for p in slots:
		if p == null:
			return true
	return false


func get_first_empty_index() -> int:
	for i in range(slots.size()):
		if slots[i] == null:
			return i
	return -1


func add_potion(potion: Potion) -> bool:
	if potion == null:
		return false
	var idx := get_first_empty_index()
	if idx < 0:
		return false
	slots[idx] = potion.duplicate(true) as Potion
	slots_changed.emit()
	return true


func remove_at(index: int) -> void:
	if index < 0 or index >= slots.size():
		return
	if slots[index] == null:
		return
	slots[index] = null
	slots_changed.emit()


func can_use_potion(potion: Potion) -> bool:
	if potion == null:
		return false
	return potion.can_use_in_context(get_tree())


func use_at(index: int, aim_anchor: Control = null) -> bool:
	return await _use_at_async(index, aim_anchor)


func _use_at_async(index: int, aim_anchor: Control = null) -> bool:
	if index < 0 or index >= slots.size():
		return false
	var potion := slots[index]
	if potion == null:
		return false
	if not potion.can_use_in_context(get_tree()):
		return false

	var targets: Array[Node] = []
	if potion.target_kind == Potion.TargetKind.SINGLE_ENEMY:
		_ensure_target_picker()
		if not is_instance_valid(_target_picker):
			return false
		var pick: Array = await _target_picker.start_pick_and_wait(aim_anchor)
		if not bool(pick[0]):
			return false
		var enemy := pick[1] as Enemy
		if not is_instance_valid(enemy):
			return false
		targets = [enemy]
	else:
		var players := get_tree().get_nodes_in_group("player")
		if players.is_empty():
			return false
		targets.assign(players)

	remove_at(index)
	await _apply_potion_effect(potion, targets)
	return true


func _apply_potion_effect(potion: Potion, targets: Array[Node]) -> void:
	if potion.target_kind == Potion.TargetKind.SINGLE_ENEMY:
		await _apply_enemy_target_potion(potion, targets)
		return
	if potion.target_kind == Potion.TargetKind.SELF:
		await _apply_self_potion(potion, targets)
		return
	await potion.perform_use_async(get_tree(), targets)


func _apply_self_potion(potion: Potion, targets: Array[Node]) -> void:
	if targets.is_empty():
		return
	var target := targets[0]
	if not is_instance_valid(target):
		return
	var players := get_tree().get_nodes_in_group("player")
	var player := players[0] as Player if not players.is_empty() else null
	var blade := player.get_blade_visual() if is_instance_valid(player) else null
	if blade == null or potion.icon == null:
		potion.perform_use(targets)
		return
	await blade.throw_self_potion_at(
		target,
		potion.icon as Texture2D,
		func() -> void:
			potion.perform_use(targets),
	)


func _apply_enemy_target_potion(potion: Potion, targets: Array[Node]) -> void:
	if targets.is_empty():
		return
	var enemy := targets[0] as Enemy
	if not is_instance_valid(enemy):
		return
	var land_sfx: AudioStream = null
	if potion.id == "explode_potion":
		land_sfx = preload("res://art/potions/explode.ogg")
	var players := get_tree().get_nodes_in_group("player")
	var player := players[0] as Player if not players.is_empty() else null
	var blade := player.get_blade_visual() if is_instance_valid(player) else null
	if blade == null or potion.icon == null:
		potion.perform_use(targets)
		return
	await blade.throw_enemy_potion_at(
		enemy,
		potion.icon as Texture2D,
		func() -> void:
			potion.perform_use(targets),
		land_sfx,
	)


func restore_from_ids(ids: PackedStringArray) -> void:
	slots.clear()
	var restore_count := maxi(DEFAULT_SLOTS, ids.size())
	for _i in range(restore_count):
		slots.append(null)
	for i in range(mini(slots.size(), ids.size())):
		var id := String(ids[i])
		if id.is_empty():
			continue
		slots[i] = GameContent.load_potion_for_save(id)
	slots_changed.emit()


func get_ids_for_save() -> PackedStringArray:
	var out := PackedStringArray()
	out.resize(slots.size())
	for i in range(slots.size()):
		var p: Potion = slots[i]
		out[i] = p.id if p != null else ""
	return out
