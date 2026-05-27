class_name PotionHandler
extends Node

const MAX_SLOTS := 3
const TARGET_PICKER_SCENE := preload("res://scenes/potion_handler/potion_target_picker.tscn")

signal slots_changed

var slots: Array[Potion] = [null, null, null]

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


func has_empty_slot() -> bool:
	for p in slots:
		if p == null:
			return true
	return false


func get_first_empty_index() -> int:
	for i in range(MAX_SLOTS):
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
	if index < 0 or index >= MAX_SLOTS:
		return
	if slots[index] == null:
		return
	slots[index] = null
	slots_changed.emit()


func can_use_now() -> bool:
	return Potion.can_use_in_context_static(get_tree())


func use_at(index: int, aim_anchor: Control = null) -> bool:
	return await _use_at_async(index, aim_anchor)


func _use_at_async(index: int, aim_anchor: Control = null) -> bool:
	if index < 0 or index >= MAX_SLOTS:
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

	potion.perform_use(targets)
	remove_at(index)
	return true


func restore_from_ids(ids: PackedStringArray) -> void:
	slots = [null, null, null]
	for i in range(mini(MAX_SLOTS, ids.size())):
		var id := String(ids[i])
		if id.is_empty():
			continue
		slots[i] = GameContent.load_potion_for_save(id)
	slots_changed.emit()


func get_ids_for_save() -> PackedStringArray:
	var out := PackedStringArray()
	out.resize(MAX_SLOTS)
	for i in range(MAX_SLOTS):
		var p: Potion = slots[i]
		out[i] = p.id if p != null else ""
	return out
