class_name ShadowSamuraiAI
extends EnemyActionPicker

const SWIFT_STATUS := preload("res://statuses/swift.tres")

const SLOT_STRIKE_1X6 := 0
const SLOT_STRIKE_2X3 := 1
const SLOT_STRIKE_3X2 := 2
const SLOT_STRENGTH_BUFF := 3
## 旧版五回合循环中 Strike6 的槽位 id（已移除，仅用于存档迁移）。
const _LEGACY_SLOT_STRIKE_6 := 3
const _LEGACY_SLOT_STRENGTH_BUFF := 4

## 长度 4：前 3 为攻击槽随机序，末位固定强化。
var _cycle_slots: Array[int] = []
var _cycle_index: int = 0
var _swift_running: bool = false


func _ready() -> void:
	super._ready()
	if not _try_restore_cycle_from_snapshot():
		_build_cycle_slots()
	call_deferred("_sync_cycle_to_snapshot")
	call_deferred("_apply_swift_status")
	if not Events.card_play_finished.is_connected(_on_card_play_finished):
		Events.card_play_finished.connect(_on_card_play_finished)
	if not Events.enemy_action_completed.is_connected(_on_enemy_action_completed):
		Events.enemy_action_completed.connect(_on_enemy_action_completed)


func _exit_tree() -> void:
	if Events.card_play_finished.is_connected(_on_card_play_finished):
		Events.card_play_finished.disconnect(_on_card_play_finished)
	if Events.enemy_action_completed.is_connected(_on_enemy_action_completed):
		Events.enemy_action_completed.disconnect(_on_enemy_action_completed)


func _build_cycle_slots() -> void:
	_cycle_slots = [SLOT_STRIKE_1X6, SLOT_STRIKE_2X3, SLOT_STRIKE_3X2]
	RNG.array_shuffle(_cycle_slots)
	_cycle_slots.append(SLOT_STRENGTH_BUFF)


func _try_restore_cycle_from_snapshot() -> bool:
	var run := get_tree().get_first_node_in_group("run") as Run
	if run == null or run.save_data == null or run.save_data.combat_snapshot == null:
		return false
	var snap: CombatSnapshot = run.save_data.combat_snapshot
	var slots := snap.shadow_samurai_cycle_slots
	if slots.size() == 5:
		_cycle_slots.clear()
		for i in range(4):
			var slot: int = slots[i]
			if slot != _LEGACY_SLOT_STRIKE_6:
				_cycle_slots.append(slot)
		_cycle_slots.append(SLOT_STRENGTH_BUFF)
		_cycle_index = 0
		return _cycle_slots.size() == 4
	if not snap.has_shadow_samurai_cycle():
		return false
	_cycle_slots.clear()
	for slot: int in slots:
		_cycle_slots.append(slot)
	_cycle_index = 0
	return true


func write_cycle_to_snapshot(snapshot: CombatSnapshot) -> void:
	if snapshot == null or _cycle_slots.size() != 4:
		return
	snapshot.shadow_samurai_cycle_slots = PackedInt32Array(_cycle_slots)


func _sync_cycle_to_snapshot() -> void:
	var run := get_tree().get_first_node_in_group("run") as Run
	if run == null or run.save_data == null or run.save_data.combat_snapshot == null:
		return
	write_cycle_to_snapshot(run.save_data.combat_snapshot)


func get_action() -> EnemyAction:
	if _cycle_slots.is_empty():
		_build_cycle_slots()
	return _action_for_slot(_cycle_slots[_cycle_index])


func get_first_conditional_action() -> EnemyAction:
	return null


func notify_picker_action_finished() -> void:
	_cycle_index = (_cycle_index + 1) % _cycle_slots.size()


func _action_for_slot(slot: int) -> EnemyAction:
	match slot:
		SLOT_STRIKE_1X6:
			return $Strike1x6 as EnemyAction
		SLOT_STRIKE_2X3:
			return $Strike2x3 as EnemyAction
		SLOT_STRIKE_3X2:
			return $Strike3x2 as EnemyAction
		SLOT_STRENGTH_BUFF:
			return $StrengthBuff as EnemyAction
	return $Strike1x6 as EnemyAction


func _apply_swift_status() -> void:
	if not is_instance_valid(enemy):
		return
	var se := StatusEffect.new()
	se.status = SWIFT_STATUS.duplicate()
	se.execute([enemy])


func _on_card_play_finished(_card: Card) -> void:
	if Events.is_combat_ended() or not is_instance_valid(enemy):
		return
	var enemy_handler := get_tree().get_first_node_in_group("enemy_handler") as EnemyHandler
	if enemy_handler and not enemy_handler.acting_enemies.is_empty():
		return
	if _swift_running:
		return
	var swift := SwiftStatus.get_on_enemy(enemy)
	if swift == null:
		return
	if swift.record_card_played():
		swift.reset_counter()
		_queue_swift_interrupt()


func _queue_swift_interrupt() -> void:
	if _swift_running or Events.is_combat_ended():
		return
	call_deferred("_run_swift_interrupt")


func _run_swift_interrupt() -> void:
	if _swift_running or Events.is_combat_ended() or not is_instance_valid(enemy):
		return
	if enemy.current_action == null:
		enemy.update_action()
	if enemy.current_action == null:
		return
	_swift_running = true
	var ph := get_tree().get_first_node_in_group("player_handler") as PlayerHandler
	if ph and is_instance_valid(ph.hand):
		ph.hand.disable_hand()
	await enemy.execute_current_action_interrupt()
	_swift_running = false
	if is_instance_valid(enemy):
		enemy.update_intent()
	if not is_instance_valid(enemy) or Events.is_combat_ended():
		return
	_try_enable_player_hand_after_swift()


func _try_enable_player_hand_after_swift() -> void:
	var ph := get_tree().get_first_node_in_group("player_handler") as PlayerHandler
	if ph == null or not is_instance_valid(ph.hand):
		return
	var enemy_handler := get_tree().get_first_node_in_group("enemy_handler") as EnemyHandler
	if enemy_handler != null and not enemy_handler.acting_enemies.is_empty():
		return
	ph.hand.call_deferred("enable_hand")


func _on_enemy_action_completed(completed_enemy: Enemy) -> void:
	if completed_enemy != enemy or not is_instance_valid(enemy):
		return
	notify_picker_action_finished()
	enemy.current_action = null
	enemy.update_action()
	enemy.update_intent()
