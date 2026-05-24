class_name RelicHandler
extends HBoxContainer

signal relics_activated(type: Relic.Type)

const RELIC_APPLY_INTERVAL := 0.5
const RELIC_UI = preload("res://scenes/relic_handler/relic_ui.tscn")

@onready var relics_control: RelicsControl = $RelicsControl
@onready var relics: HBoxContainer = %Relics


func _ready() -> void:
	relics.child_exiting_tree.connect(_on_relics_child_exiting_tree)


func activate_relics_by_type(type: Relic.Type) -> void:
	if type == Relic.Type.EVENT_BASED:
		return
		
	var relic_queue: Array[RelicUI] = _get_all_relic_ui_nodes().filter(
		func(relic_ui: RelicUI):
			return relic_ui.relic.type == type
	)
	if relic_queue.is_empty():
		relics_activated.emit(type)
		return
	
	if Events.is_combat_ended():
		for relic_ui: RelicUI in relic_queue:
			relic_ui.relic.activate_relic(relic_ui)
		relics_activated.emit(type)
		return
	
	var tween := create_tween()
	for relic_ui: RelicUI in relic_queue:
		tween.tween_callback(relic_ui.relic.activate_relic.bind(relic_ui))
		tween.tween_interval(RELIC_APPLY_INTERVAL)
	
	tween.finished.connect(func(): relics_activated.emit(type))


func add_relics(relics_array: Array[Relic], apply_persistent_pickup: bool = true) -> void:
	print("add_relics: 尝试添加 %d 个遗物" % relics_array.size())
	var added := 0
	for relic: Relic in relics_array:
		if not is_instance_valid(relic):
			push_warning("add_relics: 跳过无效的遗物实例")
			continue
		if relic.id.is_empty():
			push_warning("add_relics: 跳过ID为空的遗物")
			continue
		if not has_relic(relic.id):
			add_relic(relic, apply_persistent_pickup)
			added += 1
		else:
			print("add_relics: 跳过重复的遗物 %s" % relic.id)
	print("add_relics: 成功添加 %d 个遗物" % added)


func add_relic(relic: Relic, apply_persistent_pickup: bool = true) -> void:
	if has_relic(relic.id):
		return
	
	var new_relic_ui := RELIC_UI.instantiate() as RelicUI
	relics.add_child(new_relic_ui)
	new_relic_ui.relic = relic
	if apply_persistent_pickup:
		var run := get_tree().get_first_node_in_group("run") as Run
		if run:
			relic.apply_persistent_pickup_on_acquire(run)
	new_relic_ui.relic.initialize_relic(new_relic_ui)


## 异步添加遗物，等待 persistent_pickup 效果完成（用于战斗奖励领取流程）
## 效果全部完成后再挂到遗物栏，避免「保存退出/读档」时栏上已有遗物但效果未确认。
func add_relic_async(relic: Relic) -> void:
	if has_relic(relic.id):
		return
	
	var run := get_tree().get_first_node_in_group("run") as Run
	if run:
		await relic.apply_persistent_pickup_on_acquire_async(run)
	
	if has_relic(relic.id):
		return
	
	var new_relic_ui := RELIC_UI.instantiate() as RelicUI
	relics.add_child(new_relic_ui)
	new_relic_ui.relic = relic
	new_relic_ui.relic.initialize_relic(new_relic_ui)


func has_relic(id: String) -> bool:
	for relic_ui: RelicUI in relics.get_children():
		if relic_ui.relic.id == id and is_instance_valid(relic_ui):
			return true

	return false


func remove_relic_by_id(id: String) -> bool:
	for c in relics.get_children():
		var ru := c as RelicUI
		if ru == null or not is_instance_valid(ru) or ru.relic == null:
			continue
		if ru.relic.id == id:
			ru.queue_free()
			return true
	return false


func get_all_relics() -> Array[Relic]:
	var relic_ui_nodes := _get_all_relic_ui_nodes()
	var relics_array: Array[Relic] = []
	
	for relic_ui: RelicUI in relic_ui_nodes:
		if is_instance_valid(relic_ui) and is_instance_valid(relic_ui.relic):
			relics_array.append(relic_ui.relic)
		else:
			push_warning("get_all_relics: 跳过无效的 relic_ui 或 relic")
	
	return relics_array


func _get_all_relic_ui_nodes() -> Array[RelicUI]:
	var all_relics: Array[RelicUI] = []
	for relic_ui: RelicUI in relics.get_children():
		all_relics.append(relic_ui)
		
	return all_relics


func _on_relics_child_exiting_tree(relic_ui: RelicUI) -> void:
	if not relic_ui:
		return
	
	if relic_ui.relic:
		relic_ui.relic.deactivate_relic(relic_ui)


func revert_persistent_pickups_not_in(
	character: CharacterStats,
	allowed_relic_ids: PackedStringArray
) -> void:
	if character == null:
		return
	var allowed: Dictionary = {}
	for relic_id in allowed_relic_ids:
		var id := String(relic_id)
		if not id.is_empty():
			allowed[id] = true
	for relic: Relic in get_all_relics():
		if relic == null or relic.id.is_empty():
			continue
		if not allowed.has(relic.id):
			relic.revert_persistent_pickup_on_rollback(character)


func revert_pending_relic_pickup_if_applied(
	character: CharacterStats,
	relic_id: String,
	pre_max_health: int,
	pre_max_mana: int
) -> void:
	if character == null or relic_id.is_empty():
		return
	var pickup_applied := (
		pre_max_health >= 0
		and character.max_health > pre_max_health
	) or (
		pre_max_mana >= 0
		and character.max_mana > pre_max_mana
	)
	if not pickup_applied:
		return
	var relic := GameContent.load_relic_for_save(relic_id)
	if relic != null:
		relic.revert_persistent_pickup_on_rollback(character)


func restore_relics_from_ids(
	relic_ids: PackedStringArray,
	apply_persistent_pickup: bool = false,
	immediate_clear: bool = true
) -> Array[Relic]:
	if immediate_clear:
		clear_relics_immediate()
	else:
		clear_relics()
	for relic_id in relic_ids:
		var relic := GameContent.load_relic_for_save(String(relic_id))
		if relic != null:
			add_relic(relic, apply_persistent_pickup)
	return get_all_relics()


func clear_relics() -> void:
	for relic_ui: RelicUI in relics.get_children():
		if is_instance_valid(relic_ui):
			relic_ui.queue_free()


## 读档回退等需要立刻刷新遗物栏时用（避免 queue_free 延迟导致栏上仍显示未确认的遗物）
func clear_relics_immediate() -> void:
	var children := relics.get_children().duplicate()
	for child in children:
		if is_instance_valid(child):
			## 仅 free；deactivate 由 child_exiting_tree 触发一次，避免重复 disconnect
			child.free()
