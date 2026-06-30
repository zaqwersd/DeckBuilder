class_name RunBgm
extends RefCounted

## Act1 / Act3 后半段：第 8 层宝箱打开后永久叠加 tense 层。
const TREASURE_TENSE_ROW := 8


static func on_act_entered(act: int) -> void:
	MusicPlayer.tape_change_to_act(act)


static func on_run_exit() -> void:
	MusicPlayer.begin_run_exit_fade()


static func sync_for_run(run: Run, instant_overlays: bool = false) -> void:
	if run == null:
		return
	_sync_act(run, null, instant_overlays)


static func sync_for_run_after_load(run: Run) -> void:
	if run == null:
		return
	await MusicPlayer.ensure_act1_streams_ready()
	_sync_act(run, null, true)


static func on_battle_music(run: Run, room: Room) -> void:
	if run == null:
		return
	_sync_act(run, room, false)


static func uses_tense_unlock(act: int) -> bool:
	return act == 1 or act == 3


static func on_tense_unlocked(run: Run) -> void:
	if run == null or run.save_data == null or not uses_tense_unlock(run.current_act):
		return
	match run.current_act:
		1:
			run.save_data.act1_tense_unlocked = true
		3:
			run.save_data.act3_tense_unlocked = true


static func try_unlock_tense_from_treasure(run: Run) -> void:
	if run == null or run.save_data == null or run.map == null:
		return
	if not uses_tense_unlock(run.current_act):
		return
	var room := run.map.last_room
	if room == null or room.type != Room.Type.TREASURE or room.row != TREASURE_TENSE_ROW:
		return
	on_tense_unlocked(run)


static func is_tense_unlocked(run: Run) -> bool:
	if run == null or run.save_data == null or not uses_tense_unlock(run.current_act):
		return false
	match run.current_act:
		1:
			return run.save_data.act1_tense_unlocked
		3:
			return run.save_data.act3_tense_unlocked
	return false


static func is_row8_tense_treasure_room(run: Run) -> bool:
	if run == null or run.map == null or not uses_tense_unlock(run.current_act):
		return false
	var room := run.map.last_room
	return (
		room != null
		and room.type == Room.Type.TREASURE
		and room.row == TREASURE_TENSE_ROW
	)


static func is_row8_tense_treasure_pre_open(run: Run) -> bool:
	if not is_row8_tense_treasure_room(run):
		return false
	return (
		run.save_data != null
		and run.save_data.pending_room_kind == SaveGame.PENDING_TREASURE
	)


static func should_skip_sync_for_treasure_silence(run: Run) -> bool:
	if MusicPlayer.is_treasure_silence_active():
		return true
	return is_row8_tense_treasure_pre_open(run) and not is_tense_unlocked(run)


static func on_row8_tense_treasure_entered() -> void:
	MusicPlayer.begin_treasure_silence_fade()


static func on_row8_tense_treasure_opened(run: Run) -> void:
	try_unlock_tense_from_treasure(run)
	MusicPlayer.start_layered_main_and_tense_from_start(run.current_act)


## 兼容旧调用
static func on_act1_tense_unlocked(run: Run) -> void:
	on_tense_unlocked(run)


static func try_unlock_act1_tense_from_treasure(run: Run) -> void:
	try_unlock_tense_from_treasure(run)


static func is_act1_tense_unlocked(run: Run) -> bool:
	return is_tense_unlocked(run) and run.current_act == 1


static func is_act1_row8_treasure_room(run: Run) -> bool:
	return is_row8_tense_treasure_room(run) and run.current_act == 1


static func is_act1_row8_treasure_pre_open(run: Run) -> bool:
	return is_row8_tense_treasure_pre_open(run) and run.current_act == 1


static func on_act1_row8_treasure_entered() -> void:
	on_row8_tense_treasure_entered()


static func on_act1_row8_treasure_opened(run: Run) -> void:
	on_row8_tense_treasure_opened(run)


static func _sync_act(run: Run, room: Room = null, instant_overlays: bool = false) -> void:
	if should_skip_sync_for_treasure_silence(run):
		return
	if room == null:
		room = _active_room(run)
	if _should_suppress_act_bgm_for_boss_room(run, room):
		MusicPlayer.request_act_boss_fade()
		return
	MusicPlayer.set_boss_suppressed(false)
	MusicPlayer.ensure_act_bgm_for_act(run.current_act)
	var phase: float = MusicPlayer.get_playback_position()
	MusicPlayer.sync_tense_overlay_for_run(run, phase, instant_overlays)
	var combat_room := _combat_room_for_run(run)
	if combat_room != null:
		MusicPlayer.play_battle_overlays_for_room(
			run.current_act,
			combat_room,
			phase,
			instant_overlays
		)
	elif _run_in_combat_without_room(run):
		pass
	else:
		MusicPlayer.fade_out_battle_overlays()


static func _combat_room_for_run(run: Run) -> Room:
	if run == null or run.save_data == null:
		return null
	if run.save_data.was_on_map:
		return null
	var snap := run.save_data.combat_snapshot
	if snap == null:
		return null
	return snap.room


static func _run_in_combat_without_room(run: Run) -> bool:
	if run == null or run.save_data == null:
		return false
	if run.save_data.was_on_map:
		return false
	return run.save_data.combat_snapshot != null


static func effective_room_type(room: Room) -> Room.Type:
	if room == null:
		return Room.Type.NOT_ASSIGNED
	if room.type == Room.Type.UNKNOWN and room.unknown_resolved_type != Room.Type.NOT_ASSIGNED:
		return room.unknown_resolved_type
	return room.type


static func _should_suppress_act_bgm_for_boss_room(run: Run, room: Room) -> bool:
	if room == null or effective_room_type(room) != Room.Type.BOSS:
		return false
	if run == null or run.save_data == null:
		return true
	# 地图上站在 Boss 节点前仍播放层 BGM，仅进战/战斗读档时静音
	return not run.save_data.was_on_map


static func _active_room(run: Run) -> Room:
	if run == null or run.save_data == null:
		return null
	var snap := run.save_data.combat_snapshot
	if snap != null and not run.save_data.was_on_map:
		return snap.room
	if run.map != null and run.map.last_room != null:
		return run.map.last_room
	return null
