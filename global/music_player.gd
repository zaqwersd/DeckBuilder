extends Node

const TAPE_FADE_DURATION := 1.0
const BATTLE_FADE_DURATION := 1.0
const OVERLAY_FADE_OUT_DURATION := 3.0

const ACT2_BGM := preload("res://art/mountains(square_wave).ogg")
const ACT3_BGM_SOURCE := preload("res://art/sanctuary(main).mp3")
const ACT3_BATTLE_BGM_SOURCE := preload("res://art/sanctuary(battle).mp3")
const ACT3_TENSE_BGM_SOURCE_PATH := "res://art/sanctuary(tense).mp3"
const ACT3_TENSE_BATTLE_BGM_SOURCE_PATH := "res://art/sanctuary(tense_battle).mp3"
const TAPE_STOP_SFX := preload("res://art/tape_stop.ogg")

const ACT1_BGM_SOURCE := preload("res://art/valley(main).mp3")
const ACT1_BATTLE_BGM_SOURCE := preload("res://art/valley(battle).mp3")
const ACT1_TENSE_BGM_SOURCE := preload("res://art/valley(tense).mp3")
const ACT1_TENSE_BATTLE_BGM_SOURCE := preload("res://art/valley(tense_battle).mp3")

const ACT1_BGM_KEY := &"act1_village"
const ACT1_BATTLE_BGM_KEY := &"act1_village_battle"
const ACT1_TENSE_BGM_KEY := &"act1_tense"
const ACT1_TENSE_BATTLE_BGM_KEY := &"act1_tense_battle"
const ACT2_BGM_KEY := &"act2_mountains"
const ACT3_BGM_KEY := &"act3_sanctuary"
const ACT3_BATTLE_BGM_KEY := &"act3_sanctuary_battle"
const ACT3_TENSE_BGM_KEY := &"act3_sanctuary_tense"
const ACT3_TENSE_BATTLE_BGM_KEY := &"act3_sanctuary_tense_battle"

const ACT1_BPM := 150.0
const ACT2_BPM := 150.0
const ACT3_BPM := 120.0
const ACT1_LOOP_BEATS := 64
const ACT1_LOOP_INTERVAL_SEC := ACT1_LOOP_BEATS * 60.0 / ACT1_BPM
## Act3 sanctuary：7/8 拍，四个小节循环（28 拍 @ 120 BPM = 14s）
const ACT3_BAR_BEATS := 7
const ACT3_LOOP_BARS := 4
const ACT3_LOOP_BEATS := ACT3_BAR_BEATS * ACT3_LOOP_BARS
const ACT3_LOOP_INTERVAL_SEC := ACT3_LOOP_BEATS * 60.0 / ACT3_BPM
const DEFAULT_BAR_BEATS := 4
const ACT1_LOOP_TRIGGER_EPS_SEC := 0.03
const ACT1_LOOP_REARM_PHASE_SEC := 0.2
const ACT1_OVERLAY_SYNC_THRESHOLD_SEC := 0.03

const BATTLE_FADE_IN_VOLUME_DB := 0.0
const TAPE_END_PITCH := 0.35
const TAPE_END_VOLUME_DB := -80.0

const ACT_BGM := {
	2: {"stream": ACT2_BGM, "key": ACT2_BGM_KEY},
}

var _bgm_player: AudioStreamPlayer
var _battle_bgm_player: AudioStreamPlayer
var _tense_bgm_player: AudioStreamPlayer
var _tense_battle_bgm_player: AudioStreamPlayer
var _act1_bgm: AudioStreamMP3
var _act1_battle_bgm: AudioStreamMP3
var _act1_tense_bgm: AudioStreamMP3
var _act1_tense_battle_bgm: AudioStreamMP3
var _act3_bgm: AudioStreamMP3
var _act3_battle_bgm: AudioStreamMP3
var _act3_tense_bgm: AudioStreamMP3
var _act3_tense_battle_bgm: AudioStreamMP3

var _tape_tween: Tween
var _overlay_volume_tweens: Dictionary = {}
var _overlay_fade_stops_on_finish: Dictionary = {}
var _overlay_volume_tween_generation: Dictionary = {}
var _tape_generation := 0
var _current_key: StringName = &""
var _battle_layer_key: StringName = &""
var _tense_battle_layer_key: StringName = &""
var _tense_layer_key: StringName = &""
var _boss_suppressed := false
var _boss_fade_requested := false
var _job_running := false
var _pending_job: Dictionary = {}
var _run_exit_fade_active := false
var _treasure_silence_active := false
## Act1：每轨主/备 ping-pong 叠放；主 BGM 实际播放相位驱动全轨同步
var _act1_loop_alt_by_primary: Dictionary = {}
var _act1_loop_leader: Dictionary = {}
var _act1_last_main_phase: float = -1.0
var _act1_loop_armed := true
var _act1_last_loop_fire_time: float = -999.0

var _act1_warmup_done := false
var _act1_warmup_running := false

signal act1_streams_ready

signal run_exit_fade_finished


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bgm_player = get_node_or_null("AudioStreamPlayer") as AudioStreamPlayer
	_battle_bgm_player = get_node_or_null("AudioStreamPlayer2") as AudioStreamPlayer
	_tense_bgm_player = get_node_or_null("AudioStreamPlayer3") as AudioStreamPlayer
	_tense_battle_bgm_player = get_node_or_null("AudioStreamPlayer4") as AudioStreamPlayer
	if _bgm_player == null or _battle_bgm_player == null or _tense_bgm_player == null or _tense_battle_bgm_player == null:
		push_error("MusicPlayer: missing AudioStreamPlayer nodes")
		return
	_bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_battle_bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_tense_bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_tense_battle_bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	call_deferred("_begin_act1_warmup_background")


func _begin_act1_warmup_background() -> void:
	await ensure_act1_streams_ready()


## 读档/开局前调用：缓存 Act1 流并预解码，避免首帧 play 卡顿。
func ensure_act1_streams_ready() -> void:
	if _act1_warmup_done:
		return
	if _act1_warmup_running:
		await act1_streams_ready
		return
	_act1_warmup_running = true
	await _warmup_act1_streams()
	_act1_warmup_done = true
	_act1_warmup_running = false
	act1_streams_ready.emit()


func await_idle_frame() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame


func _process(_delta: float) -> void:
	_process_act1_overlap_loops()
	_process_act1_overlay_sync()


func is_playing() -> bool:
	return _is_main_bgm_audible()


func _is_main_bgm_audible() -> bool:
	if _bgm_player == null:
		return false
	if _is_act1_bgm_key(_current_key):
		return _is_act1_pair_audible(_bgm_player)
	return _bgm_player.playing


func get_playback_position() -> float:
	if _bgm_player == null:
		return 0.0
	if _is_act1_bgm_key(_current_key):
		return _get_act1_main_audio_phase()
	if not _bgm_player.playing:
		return 0.0
	return _bgm_player.get_playback_position()


func set_boss_suppressed(suppressed: bool) -> void:
	_boss_suppressed = suppressed


func is_boss_suppressed() -> bool:
	return _boss_suppressed


## Compatibility helper: same as play_act_bgm(1)
func play(audio: AudioStream, single: bool = false) -> void:
	if audio == null:
		return
	_enqueue_job({
		"kind": &"play",
		"stream": _get_act1_bgm(),
		"key": ACT1_BGM_KEY,
		"tape_out": single and _is_main_bgm_audible(),
	})


func play_act_bgm(act: int) -> void:
	if _boss_suppressed:
		return
	var cfg := _act_cfg(act)
	var stream: AudioStream = cfg["stream"] as AudioStream
	if not _uses_layered_bgm(act):
		stream = _prepare_loop(stream, _bpm_for_act(act))
	_enqueue_job({
		"kind": &"play",
		"stream": stream,
		"key": cfg["key"] as StringName,
		"tape_out": _is_main_bgm_audible() and _current_key != cfg["key"],
	})


## 读档/地图同步用：不走异步 job 队列，避免与叠层淡入抢状态。
func ensure_act_bgm_for_act(act: int) -> void:
	if _run_exit_fade_active:
		_ensure_act_bgm_for_act_when_ready(act)
		return
	_apply_act_bgm_for_act(act)


func _ensure_act_bgm_for_act_when_ready(act: int) -> void:
	await _await_run_exit_fade_if_active()
	_apply_act_bgm_for_act(act)


func _apply_act_bgm_for_act(act: int) -> void:
	if _boss_suppressed:
		return
	var cfg := _act_cfg(act)
	var key := cfg["key"] as StringName
	if _current_key == key and _is_main_bgm_audible():
		return
	if _uses_layered_bgm(act):
		_ensure_layered_main_playing(act)
		return
	var stream := _prepare_loop(cfg["stream"] as AudioStream, _bpm_for_act(act))
	_start_bgm(stream, key)


func prepare_for_run_sync() -> void:
	_boss_suppressed = false
	_boss_fade_requested = false
	_treasure_silence_active = false
	_abort_pending_jobs(false)


## 退出本局后、新局/读档开始前调用：等淡出结束再执行回调，避免打断退出 Tween。
func after_run_exit_fade(callback: Callable) -> void:
	_after_run_exit_fade_dispatch(callback)


func _after_run_exit_fade_dispatch(callback: Callable) -> void:
	await _await_run_exit_fade_if_active()
	if callback.is_valid():
		callback.call()


func begin_run_exit_fade() -> void:
	if _run_exit_fade_active:
		return
	_run_exit_fade_active = true
	_run_exit_fade_async()


## 返回主菜单：结束本局淡出（若仍在进行）并立即停止一切 BGM/叠层。
func stop_for_menu_transition() -> void:
	var was_fading := _run_exit_fade_active
	_job_running = false
	_pending_job = {}
	_run_exit_fade_active = false
	_stop_immediate()
	_current_key = &""
	_boss_suppressed = false
	_boss_fade_requested = false
	if was_fading:
		run_exit_fade_finished.emit()


func tape_fade_out_and_stop_async() -> void:
	begin_run_exit_fade()


func _run_exit_fade_async() -> void:
	_job_running = false
	_pending_job = {}
	if _bgm_player != null and _is_main_bgm_audible():
		await _tape_fade_out()
	elif _any_overlay_audible():
		await _await_overlay_fades(OVERLAY_FADE_OUT_DURATION)
	_finish_run_exit_fade()


func _finish_run_exit_fade() -> void:
	_cancel_tape_tween()
	_stop_act1_overlap_pair(_bgm_player)
	_reset_player_audio_state()
	_quiet_stop_all_act1_overlays_without_cancel()
	_current_key = &""
	_boss_suppressed = false
	_boss_fade_requested = false
	_run_exit_fade_active = false
	run_exit_fade_finished.emit()


func _await_run_exit_fade_if_active() -> void:
	while _run_exit_fade_active:
		await run_exit_fade_finished


func is_treasure_silence_active() -> bool:
	return _treasure_silence_active


func begin_treasure_silence_fade() -> void:
	_treasure_silence_fade_async()


func _treasure_silence_fade_async() -> void:
	if _is_main_bgm_audible():
		await _tape_fade_out()
	elif _any_overlay_audible():
		await _await_overlay_fades(OVERLAY_FADE_OUT_DURATION)
	_stop_immediate()
	_treasure_silence_active = true


func start_layered_main_and_tense_from_start(act: int) -> void:
	_treasure_silence_active = false
	_cancel_tape_tween()
	_cancel_all_overlay_volume_tweens()
	_stop_overlay_player(_battle_bgm_player)
	_stop_overlay_player(_tense_battle_bgm_player)
	var cfg := _act_cfg(act)
	var main_stream := cfg["stream"] as AudioStreamMP3
	var main_key := cfg["key"] as StringName
	if main_stream != null and _bgm_player != null:
		_start_act1_stream_on_player(_bgm_player, main_stream, main_key, 0.0, 0.0)
		_current_key = main_key
	var tense_stream := _get_tense_bgm_for_act(act)
	var tense_key := _tense_bgm_key_for_act(act)
	if tense_stream != null and _tense_bgm_player != null:
		_start_act1_stream_on_player(
			_tense_bgm_player,
			tense_stream,
			tense_key,
			0.0,
			BATTLE_FADE_IN_VOLUME_DB
		)
		_tense_layer_key = tense_key
	_boss_suppressed = false
	_boss_fade_requested = false


func start_act1_main_and_tense_from_start() -> void:
	start_layered_main_and_tense_from_start(1)


func tape_change_to_act(act: int) -> void:
	_boss_suppressed = false
	var cfg := _act_cfg(act)
	var key := cfg["key"] as StringName
	if _current_key == key and _is_main_bgm_audible():
		return
	var stream: AudioStream = cfg["stream"] as AudioStream
	if act != 1 and act != 3:
		stream = _prepare_loop(stream, _bpm_for_act(act))
	_enqueue_job({
		"kind": &"play",
		"stream": stream,
		"key": key,
		"tape_out": _is_main_bgm_audible(),
	})


func _uses_layered_bgm(act: int) -> bool:
	return act == 1 or act == 3


func request_act_boss_fade() -> void:
	_boss_suppressed = true
	if not _is_main_bgm_audible() and not _any_overlay_audible():
		_stop_immediate()
		_current_key = &""
		return
	if _boss_fade_requested:
		return
	_boss_fade_requested = true
	_enqueue_job({"kind": &"fade_stop"})


func tape_fade_out_and_stop() -> void:
	_enqueue_job({"kind": &"fade_stop"})


func stop() -> void:
	_enqueue_job({"kind": &"stop_immediate"})


func play_battle_overlay(act: int, from_position: float = -1.0) -> void:
	play_battle_overlays_for_room(act, null, from_position)


func play_battle_overlays_for_room(
	act: int,
	room: Room = null,
	from_position: float = -1.0,
	instant: bool = false
) -> void:
	if _run_exit_fade_active or _treasure_silence_active or not _uses_layered_bgm(act) or _boss_suppressed:
		return
	if room != null and RunBgm.effective_room_type(room) == Room.Type.BOSS:
		fade_out_battle_overlays()
		return
	_ensure_layered_main_playing(act)
	var start_pos := from_position if from_position >= 0.0 else get_playback_position()
	if instant:
		_apply_battle_overlay_layers_for_room(act, room, start_pos, false)
		return
	_apply_battle_overlay_layers_for_room(act, room, start_pos, true)


func _apply_battle_overlay_layers_for_room(
	act: int,
	room: Room,
	start_pos: float,
	fade_in: bool = false
) -> void:
	if _run_exit_fade_active or _treasure_silence_active or _boss_suppressed:
		return
	var battle_stream := _get_battle_bgm_for_act(act)
	var battle_key := _battle_bgm_key_for_act(act)
	_ensure_overlay_layer(
		_battle_bgm_player,
		battle_stream,
		battle_key,
		start_pos,
		fade_in
	)
	if _uses_layered_bgm(act) and _room_uses_tense_battle(room):
		var tense_battle_stream := _get_tense_battle_bgm_for_act(act)
		if tense_battle_stream != null:
			_ensure_overlay_layer(
				_tense_battle_bgm_player,
				tense_battle_stream,
				_tense_battle_bgm_key_for_act(act),
				start_pos,
				fade_in
			)
		else:
			_fade_out_overlay_player(_tense_battle_bgm_player)
	else:
		_fade_out_overlay_player(_tense_battle_bgm_player)


func sync_tense_overlay_for_run(
	run: Run,
	from_position: float = -1.0,
	instant: bool = false
) -> void:
	if _run_exit_fade_active or _treasure_silence_active:
		return
	if run == null or not RunBgm.uses_tense_unlock(run.current_act) or not RunBgm.is_tense_unlocked(run):
		_fade_out_overlay_player(_tense_bgm_player)
		return
	var start_pos := from_position if from_position >= 0.0 else get_playback_position()
	if instant:
		_apply_tense_overlay_for_run(run, start_pos, false)
		return
	_apply_tense_overlay_for_run(run, start_pos, true)


func _apply_tense_overlay_for_run(run: Run, start_pos: float, fade_in: bool) -> void:
	if _run_exit_fade_active or _treasure_silence_active:
		return
	if run == null or not RunBgm.uses_tense_unlock(run.current_act) or not RunBgm.is_tense_unlocked(run):
		_fade_out_overlay_player(_tense_bgm_player)
		return
	_ensure_overlay_layer(
		_tense_bgm_player,
		_get_tense_bgm_for_act(run.current_act),
		_tense_bgm_key_for_act(run.current_act),
		start_pos,
		fade_in
	)


func fade_out_act1_overlays(duration: float = OVERLAY_FADE_OUT_DURATION) -> void:
	_fade_out_overlay_player(_battle_bgm_player, duration)
	_fade_out_overlay_player(_tense_battle_bgm_player, duration)
	_fade_out_overlay_player(_tense_bgm_player, duration)


func fade_out_battle_overlays() -> void:
	_fade_out_overlay_player(_battle_bgm_player)
	_fade_out_overlay_player(_tense_battle_bgm_player)


func stop_battle_overlays_immediate() -> void:
	_stop_overlay_player(_battle_bgm_player)
	_stop_overlay_player(_tense_battle_bgm_player)


func stop_all_act1_overlays_immediate() -> void:
	stop_battle_overlays_immediate()
	_stop_overlay_player(_tense_bgm_player)


func _room_uses_tense_battle(room: Room) -> bool:
	if room == null:
		return false
	var room_type := RunBgm.effective_room_type(room)
	if room_type == Room.Type.ELITE:
		return true
	if room_type == Room.Type.MONSTER:
		return MapGenerator.battle_tier_for_room(room) >= 1
	return false


func _act_cfg(act: int) -> Dictionary:
	if act == 1:
		return {"stream": _get_act1_bgm(), "key": ACT1_BGM_KEY}
	if act == 3:
		return {"stream": _get_act3_bgm(), "key": ACT3_BGM_KEY}
	if ACT_BGM.has(act):
		return ACT_BGM[act]
	return {"stream": _get_act1_bgm(), "key": ACT1_BGM_KEY}


func _battle_bgm_key_for_act(act: int) -> StringName:
	return ACT3_BATTLE_BGM_KEY if act == 3 else ACT1_BATTLE_BGM_KEY


func _get_battle_bgm_for_act(act: int) -> AudioStreamMP3:
	return _get_act3_battle_bgm() if act == 3 else _get_act1_battle_bgm()


func _ensure_act1_main_playing() -> void:
	_ensure_layered_main_playing(1)


func _ensure_layered_main_playing(act: int) -> void:
	if _run_exit_fade_active or _boss_suppressed or _bgm_player == null:
		return
	var cfg := _act_cfg(act)
	var key := cfg["key"] as StringName
	var stream := cfg["stream"] as AudioStreamMP3
	if _current_key == key and _is_act1_pair_audible(_bgm_player):
		return
	if stream == null:
		return
	_cancel_tape_tween()
	var start_pos := 0.0
	if _is_act1_pair_audible(_bgm_player):
		start_pos = _get_act1_main_audio_phase()
	_start_act1_stream_on_player(_bgm_player, stream, key, start_pos, 0.0)
	_current_key = key


func _ensure_overlay_layer(
	player: AudioStreamPlayer,
	stream: AudioStreamMP3,
	key: StringName,
	from_position: float,
	fade_in: bool = true
) -> void:
	if player == null or stream == null:
		return
	_purge_stale_overlay_tween_records_for_primary(player)
	if _overlay_primary_has_volume_fade(player):
		_cancel_overlay_fade_for_primary(player)
	var start_pos := _resolve_overlay_start_phase(from_position)
	var same_key := _layer_key_for_player(player) == key
	if same_key and _is_act1_pair_audible(player):
		_sync_act1_overlay_primary_to_main(
			player,
			start_pos,
			_act1_loop_interval_sec(),
			false
		)
		var audible_volume := _get_act1_overlay_audible_volume(player)
		if fade_in and audible_volume < BATTLE_FADE_IN_VOLUME_DB - 0.1:
			_fade_in_all_act1_overlay_voices(player)
		elif not fade_in:
			for voice: AudioStreamPlayer in _act1_playback_voices_for(player):
				if voice.playing:
					voice.volume_db = BATTLE_FADE_IN_VOLUME_DB
		return
	_cancel_overlay_fade_for_primary(player)
	_stop_act1_overlap_pair(player)
	if _is_act1_bgm_key(key):
		var start_volume := TAPE_END_VOLUME_DB if fade_in else BATTLE_FADE_IN_VOLUME_DB
		_start_act1_stream_on_player(player, stream, key, start_pos, start_volume)
		if player == _battle_bgm_player:
			_battle_layer_key = key
		elif player == _tense_battle_bgm_player:
			_tense_battle_layer_key = key
		elif player == _tense_bgm_player:
			_tense_layer_key = key
		if fade_in:
			_fade_in_all_act1_overlay_voices(player, TAPE_END_VOLUME_DB)
		else:
			_sync_act1_overlay_primary_to_main(
				player,
				start_pos,
				_act1_loop_interval_sec(),
				false
			)
		return
	player.stream = stream
	player.pitch_scale = _pitch_for_bpm(key)
	if fade_in:
		player.volume_db = TAPE_END_VOLUME_DB
		player.play(maxf(0.0, start_pos))
		if player == _battle_bgm_player:
			_battle_layer_key = key
		elif player == _tense_battle_bgm_player:
			_tense_battle_layer_key = key
		elif player == _tense_bgm_player:
			_tense_layer_key = key
		_start_player_volume_fade(
			player,
			TAPE_END_VOLUME_DB,
			BATTLE_FADE_IN_VOLUME_DB,
			BATTLE_FADE_DURATION,
			false,
			true
		)
	else:
		player.volume_db = BATTLE_FADE_IN_VOLUME_DB
		player.play(maxf(0.0, start_pos))
		if player == _battle_bgm_player:
			_battle_layer_key = key
		elif player == _tense_battle_bgm_player:
			_tense_battle_layer_key = key
		elif player == _tense_bgm_player:
			_tense_layer_key = key


func _resolve_overlay_start_phase(from_position: float) -> float:
	if _is_main_bgm_audible():
		return _get_act1_main_audio_phase()
	if from_position >= 0.0:
		return from_position
	return 0.0


func _stop_overlay_player(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	_cancel_overlay_fade_for_primary(player)
	_stop_act1_overlap_pair(player)
	if player == _battle_bgm_player:
		_battle_layer_key = &""
	elif player == _tense_battle_bgm_player:
		_tense_battle_layer_key = &""
	elif player == _tense_bgm_player:
		_tense_layer_key = &""


func _fade_out_overlay_player(player: AudioStreamPlayer, duration: float = OVERLAY_FADE_OUT_DURATION) -> void:
	if player == null:
		return
	_purge_stale_overlay_tween_records_for_primary(player)
	_cancel_overlay_fade_for_primary(player)
	if not _is_act1_pair_audible(player):
		_stop_overlay_player(player)
		return
	var fading := false
	for voice: AudioStreamPlayer in _act1_playback_voices_for(player):
		if not voice.playing:
			continue
		if voice.volume_db <= TAPE_END_VOLUME_DB + 1.0:
			continue
		_start_player_volume_fade(
			voice,
			voice.volume_db,
			TAPE_END_VOLUME_DB,
			duration,
			voice == player,
			false
		)
		fading = true
	if not fading:
		_stop_overlay_player(player)


func _fade_in_all_act1_overlay_voices(
	primary: AudioStreamPlayer,
	start_volume: float = -INF
) -> void:
	if primary == null:
		return
	for voice: AudioStreamPlayer in _act1_playback_voices_for(primary):
		if not voice.playing:
			continue
		if voice.volume_db >= BATTLE_FADE_IN_VOLUME_DB - 0.1:
			continue
		var from_volume := voice.volume_db if start_volume == -INF else start_volume
		_start_player_volume_fade(
			voice,
			from_volume,
			BATTLE_FADE_IN_VOLUME_DB,
			BATTLE_FADE_DURATION,
			false,
			true
		)


func _has_running_overlay_volume_tween(player: AudioStreamPlayer) -> bool:
	if player == null or not _overlay_volume_tweens.has(player):
		return false
	var tween: Tween = _overlay_volume_tweens[player] as Tween
	return tween != null and tween.is_valid() and tween.is_running()


func _purge_stale_overlay_tween_record(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	if not _overlay_volume_tweens.has(player):
		_overlay_fade_stops_on_finish.erase(player)
		return
	if _has_running_overlay_volume_tween(player):
		return
	_overlay_volume_tweens.erase(player)
	_overlay_fade_stops_on_finish.erase(player)


func _purge_stale_overlay_tween_records_for_primary(primary: AudioStreamPlayer) -> void:
	if primary == null:
		return
	for voice: AudioStreamPlayer in _act1_all_voices_for(primary):
		_purge_stale_overlay_tween_record(voice)


func _overlay_primary_has_volume_fade(primary: AudioStreamPlayer) -> bool:
	if primary == null:
		return false
	_purge_stale_overlay_tween_records_for_primary(primary)
	for voice: AudioStreamPlayer in _act1_playback_voices_for(primary):
		if _has_running_overlay_volume_tween(voice):
			return true
	return false


func _invalidate_overlay_volume_tween(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	_overlay_volume_tween_generation[player] = (
		int(_overlay_volume_tween_generation.get(player, 0)) + 1
	)


func _clear_overlay_tween_state_for_primary(primary: AudioStreamPlayer) -> void:
	if primary == null:
		return
	for voice: AudioStreamPlayer in _act1_all_voices_for(primary):
		if _overlay_volume_tweens.has(voice):
			var tween: Tween = _overlay_volume_tweens[voice] as Tween
			if tween != null and tween.is_valid():
				tween.kill()
		_overlay_volume_tweens.erase(voice)
		_overlay_fade_stops_on_finish.erase(voice)
		_invalidate_overlay_volume_tween(voice)


func _layer_key_for_player(player: AudioStreamPlayer) -> StringName:
	if player == _battle_bgm_player:
		return _battle_layer_key
	if player == _tense_battle_bgm_player:
		return _tense_battle_layer_key
	if player == _tense_bgm_player:
		return _tense_layer_key
	return &""


func _start_player_volume_fade(
	player: AudioStreamPlayer,
	start_volume: float,
	target_volume: float,
	duration: float,
	stop_when_done: bool = false,
	fade_in: bool = false
) -> void:
	if player == null:
		return
	_cancel_overlay_volume_tween(player)
	var generation := int(_overlay_volume_tween_generation.get(player, 0)) + 1
	_overlay_volume_tween_generation[player] = generation
	player.volume_db = start_volume
	var tween := _create_player_volume_tween(player)
	if tween == null:
		_overlay_volume_tween_generation.erase(player)
		return
	var step := tween.tween_property(
		player,
		"volume_db",
		target_volume,
		maxf(duration, 0.001)
	)
	step.from(start_volume)
	if fade_in:
		step.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	else:
		step.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_overlay_volume_tweens[player] = tween
	if stop_when_done:
		_overlay_fade_stops_on_finish[player] = true
	else:
		_overlay_fade_stops_on_finish.erase(player)
	tween.finished.connect(
		_on_overlay_volume_tween_finished.bind(player, generation),
		CONNECT_ONE_SHOT
	)


func _on_overlay_volume_tween_finished(player: AudioStreamPlayer, generation: int) -> void:
	if int(_overlay_volume_tween_generation.get(player, -1)) != generation:
		return
	var should_stop := bool(_overlay_fade_stops_on_finish.erase(player))
	_overlay_volume_tweens.erase(player)
	_overlay_volume_tween_generation.erase(player)
	if not is_instance_valid(player):
		return
	if should_stop:
		var primary := _act1_overlap_primary_for(player)
		_clear_overlay_tween_state_for_primary(primary)
		_stop_act1_overlap_pair(primary)
		if primary == _battle_bgm_player:
			_battle_layer_key = &""
		elif primary == _tense_battle_bgm_player:
			_tense_battle_layer_key = &""
		elif primary == _tense_bgm_player:
			_tense_layer_key = &""
		return
	if player.volume_db <= TAPE_END_VOLUME_DB + 1.0 and player.playing:
		var primary := _act1_overlap_primary_for(player)
		var leader := _act1_loop_leader_for(primary)
		if player != leader:
			player.stop()


func _cancel_overlay_fade_for_primary(primary: AudioStreamPlayer) -> void:
	if primary == null:
		return
	for voice: AudioStreamPlayer in _act1_all_voices_for(primary):
		_cancel_overlay_volume_tween(voice)


func _cancel_overlay_volume_tween(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	if _overlay_volume_tweens.has(player):
		var tween: Tween = _overlay_volume_tweens[player] as Tween
		_overlay_volume_tweens.erase(player)
		if tween != null and tween.is_valid():
			tween.kill()
	_overlay_fade_stops_on_finish.erase(player)
	_invalidate_overlay_volume_tween(player)


func _cancel_all_overlay_volume_tweens() -> void:
	var players: Array = _overlay_volume_tweens.keys()
	for player_variant: Variant in players:
		_cancel_overlay_volume_tween(player_variant as AudioStreamPlayer)


func _overlay_primary_is_fading_out_to_silence(primary: AudioStreamPlayer) -> bool:
	if primary == null:
		return false
	_purge_stale_overlay_tween_records_for_primary(primary)
	for voice: AudioStreamPlayer in _act1_playback_voices_for(primary):
		if not _overlay_fade_stops_on_finish.get(voice, false):
			continue
		if _has_running_overlay_volume_tween(voice):
			return true
	return false


func _is_overlay_fading_out_to_silence(player: AudioStreamPlayer) -> bool:
	return _overlay_primary_is_fading_out_to_silence(_act1_overlap_primary_for(player))


func _await_player_overlay_tween(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	_purge_stale_overlay_tween_record(player)
	while _has_running_overlay_volume_tween(player):
		var tween: Tween = _overlay_volume_tweens[player] as Tween
		await tween.finished
		_purge_stale_overlay_tween_record(player)


func _await_overlay_fades(duration: float = OVERLAY_FADE_OUT_DURATION) -> void:
	var players_to_wait: Array[AudioStreamPlayer] = []
	for player: AudioStreamPlayer in [_battle_bgm_player, _tense_battle_bgm_player, _tense_bgm_player]:
		if player == null or not _is_act1_pair_audible(player):
			continue
		if player.volume_db <= TAPE_END_VOLUME_DB + 1.0:
			var alt := _act1_loop_alt(player)
			if alt == null or not alt.playing or alt.volume_db <= TAPE_END_VOLUME_DB + 1.0:
				continue
		players_to_wait.append(player)
		_fade_out_overlay_player(player, duration)
	for player: AudioStreamPlayer in players_to_wait:
		await _await_player_overlay_tween(player)
		var alt := _act1_loop_alt(player)
		if alt != null:
			await _await_player_overlay_tween(alt)


func _abort_pending_jobs(cancel_overlay_fades: bool = true) -> void:
	_job_running = false
	_pending_job = {}
	if _run_exit_fade_active:
		return
	_cancel_tape_tween()
	if cancel_overlay_fades:
		_cancel_all_overlay_volume_tweens()


func _any_overlay_audible() -> bool:
	for player: AudioStreamPlayer in [_battle_bgm_player, _tense_battle_bgm_player, _tense_bgm_player]:
		if player == null or not _is_act1_pair_audible(player):
			continue
		if player.volume_db > TAPE_END_VOLUME_DB + 1.0:
			return true
		var alt := _act1_loop_alt(player)
		if alt != null and alt.playing and alt.volume_db > TAPE_END_VOLUME_DB + 1.0:
			return true
	return false


func _enqueue_job(job: Dictionary) -> void:
	if _job_running:
		_pending_job = job
		return
	_run_job(job)


func _run_job(job: Dictionary) -> void:
	await _await_run_exit_fade_if_active()
	_job_running = true
	match job.get("kind", &""):
		&"play":
			await _play_job(
				job.get("stream") as AudioStream,
				job.get("key", &"") as StringName,
				bool(job.get("tape_out", false))
			)
		&"fade_stop":
			if _is_main_bgm_audible():
				await _tape_fade_out()
			elif _any_overlay_audible():
				await _await_overlay_fades(OVERLAY_FADE_OUT_DURATION)
			_stop_immediate()
			_current_key = &""
			_boss_fade_requested = false
		&"stop_immediate":
			_cancel_tape_tween()
			_stop_immediate()
			_current_key = &""
			_boss_fade_requested = false
	_job_running = false
	if not _pending_job.is_empty():
		var next := _pending_job
		_pending_job = {}
		_run_job(next)


func _play_job(stream: AudioStream, key: StringName, tape_out: bool) -> void:
	if stream == null:
		return
	if _current_key == key and (_bgm_player.playing or (_is_act1_bgm_key(key) and _is_act1_pair_audible(_bgm_player))):
		return
	if tape_out:
		if _is_main_bgm_audible():
			await _tape_fade_out()
		elif _any_overlay_audible():
			await _await_overlay_fades(OVERLAY_FADE_OUT_DURATION)
		_quiet_stop_all_act1_overlays()
	_start_bgm(stream, key)


func _start_bgm(stream: AudioStream, key: StringName) -> void:
	if _run_exit_fade_active:
		return
	_cancel_tape_tween()
	if _is_act1_bgm_key(key):
		_start_act1_stream_on_player(_bgm_player, stream, key, 0.0, 0.0)
	else:
		_stop_act1_overlap_pair(_bgm_player)
		_bgm_player.stream = stream
		_bgm_player.pitch_scale = _pitch_for_bpm(key)
		_bgm_player.volume_db = 0.0
		_bgm_player.play()
	_current_key = key
	_boss_fade_requested = false


func _pitch_for_bpm(key: StringName) -> float:
	if (
		key == ACT1_BGM_KEY
		or key == ACT1_BATTLE_BGM_KEY
		or key == ACT1_TENSE_BGM_KEY
		or key == ACT1_TENSE_BATTLE_BGM_KEY
		or key == ACT3_BGM_KEY
		or key == ACT3_BATTLE_BGM_KEY
		or key == ACT3_TENSE_BGM_KEY
		or key == ACT3_TENSE_BATTLE_BGM_KEY
	):
		return 1.0
	if key == ACT2_BGM_KEY:
		return ACT2_BPM / ACT1_BPM
	return 1.0


func _get_act1_bgm() -> AudioStreamMP3:
	if _act1_bgm != null:
		return _act1_bgm
	_act1_bgm = _configure_act1_stream(ACT1_BGM_SOURCE)
	return _act1_bgm


func _get_act1_battle_bgm() -> AudioStreamMP3:
	if _act1_battle_bgm != null:
		return _act1_battle_bgm
	_act1_battle_bgm = _configure_act1_stream(ACT1_BATTLE_BGM_SOURCE)
	return _act1_battle_bgm


func _get_act1_tense_bgm() -> AudioStreamMP3:
	if _act1_tense_bgm != null:
		return _act1_tense_bgm
	_act1_tense_bgm = _configure_act1_stream(ACT1_TENSE_BGM_SOURCE)
	return _act1_tense_bgm


func _get_act1_tense_battle_bgm() -> AudioStreamMP3:
	if _act1_tense_battle_bgm != null:
		return _act1_tense_battle_bgm
	_act1_tense_battle_bgm = _configure_act1_stream(ACT1_TENSE_BATTLE_BGM_SOURCE)
	return _act1_tense_battle_bgm


func _get_act3_bgm() -> AudioStreamMP3:
	if _act3_bgm != null:
		return _act3_bgm
	_act3_bgm = _configure_act3_stream(ACT3_BGM_SOURCE)
	return _act3_bgm


func _get_act3_battle_bgm() -> AudioStreamMP3:
	if _act3_battle_bgm != null:
		return _act3_battle_bgm
	_act3_battle_bgm = _configure_act3_stream(ACT3_BATTLE_BGM_SOURCE)
	return _act3_battle_bgm


func _get_act3_tense_bgm() -> AudioStreamMP3:
	if _act3_tense_bgm != null:
		return _act3_tense_bgm
	if not ResourceLoader.exists(ACT3_TENSE_BGM_SOURCE_PATH):
		return null
	var source := load(ACT3_TENSE_BGM_SOURCE_PATH) as AudioStream
	if source == null:
		return null
	_act3_tense_bgm = _configure_act3_stream(source)
	return _act3_tense_bgm


func _get_act3_tense_battle_bgm() -> AudioStreamMP3:
	if _act3_tense_battle_bgm != null:
		return _act3_tense_battle_bgm
	if not ResourceLoader.exists(ACT3_TENSE_BATTLE_BGM_SOURCE_PATH):
		return null
	var source := load(ACT3_TENSE_BATTLE_BGM_SOURCE_PATH) as AudioStream
	if source == null:
		return null
	_act3_tense_battle_bgm = _configure_act3_stream(source)
	return _act3_tense_battle_bgm


func _get_tense_bgm_for_act(act: int) -> AudioStreamMP3:
	return _get_act3_tense_bgm() if act == 3 else _get_act1_tense_bgm()


func _tense_bgm_key_for_act(act: int) -> StringName:
	return ACT3_TENSE_BGM_KEY if act == 3 else ACT1_TENSE_BGM_KEY


func _get_tense_battle_bgm_for_act(act: int) -> AudioStreamMP3:
	return _get_act3_tense_battle_bgm() if act == 3 else _get_act1_tense_battle_bgm()


func _tense_battle_bgm_key_for_act(act: int) -> StringName:
	return ACT3_TENSE_BATTLE_BGM_KEY if act == 3 else ACT1_TENSE_BATTLE_BGM_KEY


func _get_act1_stream_for_key(key: StringName) -> AudioStreamMP3:
	match key:
		ACT1_BGM_KEY:
			return _get_act1_bgm()
		ACT1_BATTLE_BGM_KEY:
			return _get_act1_battle_bgm()
		ACT1_TENSE_BGM_KEY:
			return _get_act1_tense_bgm()
		ACT1_TENSE_BATTLE_BGM_KEY:
			return _get_act1_tense_battle_bgm()
		ACT3_BGM_KEY:
			return _get_act3_bgm()
		ACT3_BATTLE_BGM_KEY:
			return _get_act3_battle_bgm()
		ACT3_TENSE_BGM_KEY:
			return _get_act3_tense_bgm()
		ACT3_TENSE_BATTLE_BGM_KEY:
			return _get_act3_tense_battle_bgm()
		_:
			return null


func _configure_act1_stream(source: AudioStream) -> AudioStreamMP3:
	var stream := source.duplicate() as AudioStreamMP3
	stream.loop = false
	stream.loop_offset = 0.0
	stream.bpm = ACT1_BPM
	stream.beat_count = ACT1_LOOP_BEATS
	stream.bar_beats = DEFAULT_BAR_BEATS
	return stream


func _configure_act3_stream(source: AudioStream) -> AudioStreamMP3:
	var stream := source.duplicate() as AudioStreamMP3
	## 按 beat_count 定时回到 loop_offset，不裁切资源、不 ping-pong 截尾音。
	stream.loop = true
	stream.loop_offset = 0.0
	stream.bpm = ACT3_BPM
	stream.beat_count = ACT3_LOOP_BEATS
	stream.bar_beats = ACT3_BAR_BEATS
	return stream


func _warmup_act1_streams() -> void:
	var pairs: Array[Dictionary] = [
		{"player": _bgm_player, "stream": _get_act1_bgm(), "key": ACT1_BGM_KEY},
		{
			"player": _battle_bgm_player,
			"stream": _get_act1_battle_bgm(),
			"key": ACT1_BATTLE_BGM_KEY,
		},
		{"player": _tense_bgm_player, "stream": _get_act1_tense_bgm(), "key": ACT1_TENSE_BGM_KEY},
		{
			"player": _tense_battle_bgm_player,
			"stream": _get_act1_tense_battle_bgm(),
			"key": ACT1_TENSE_BATTLE_BGM_KEY,
		},
		{"player": _bgm_player, "stream": _get_act3_bgm(), "key": ACT3_BGM_KEY},
		{
			"player": _battle_bgm_player,
			"stream": _get_act3_battle_bgm(),
			"key": ACT3_BATTLE_BGM_KEY,
		},
		{"player": _tense_bgm_player, "stream": _get_act3_tense_bgm(), "key": ACT3_TENSE_BGM_KEY},
	]
	var act3_tense_battle := _get_act3_tense_battle_bgm()
	if act3_tense_battle != null:
		pairs.append(
			{
				"player": _tense_battle_bgm_player,
				"stream": act3_tense_battle,
				"key": ACT3_TENSE_BATTLE_BGM_KEY,
			}
		)
	for entry: Dictionary in pairs:
		await _prime_act1_player(
			entry["player"] as AudioStreamPlayer,
			entry["stream"] as AudioStreamMP3,
			entry["key"] as StringName
		)


func _prime_act1_player(
	player: AudioStreamPlayer,
	stream: AudioStreamMP3,
	key: StringName
) -> void:
	if player == null or stream == null:
		return
	var saved_stream := player.stream
	var saved_pitch := player.pitch_scale
	var saved_volume := player.volume_db
	var was_playing := player.playing
	var saved_pos := player.get_playback_position() if was_playing else 0.0
	player.stream = stream
	player.pitch_scale = _pitch_for_bpm(key)
	player.volume_db = TAPE_END_VOLUME_DB
	player.play(0.0)
	for _i in 3:
		await get_tree().process_frame
	player.stop()
	if was_playing and saved_stream != null:
		player.stream = saved_stream
		player.pitch_scale = saved_pitch
		player.volume_db = saved_volume
		player.play(saved_pos)
	else:
		player.stream = saved_stream
		player.pitch_scale = saved_pitch
		player.volume_db = saved_volume


func _is_act1_bgm_key(key: StringName) -> bool:
	return (
		key == ACT1_BGM_KEY
		or key == ACT1_BATTLE_BGM_KEY
		or key == ACT1_TENSE_BGM_KEY
		or key == ACT1_TENSE_BATTLE_BGM_KEY
		or key == ACT3_BGM_KEY
		or key == ACT3_BATTLE_BGM_KEY
		or key == ACT3_TENSE_BGM_KEY
		or key == ACT3_TENSE_BATTLE_BGM_KEY
	)


func _is_act3_bgm_key(key: StringName) -> bool:
	return (
		key == ACT3_BGM_KEY
		or key == ACT3_BATTLE_BGM_KEY
		or key == ACT3_TENSE_BGM_KEY
		or key == ACT3_TENSE_BATTLE_BGM_KEY
	)


func _act1_loop_interval_sec() -> float:
	if _is_act3_bgm_key(_current_key):
		return ACT3_LOOP_INTERVAL_SEC
	return ACT1_LOOP_INTERVAL_SEC


func _ensure_act1_loop_alt(primary: AudioStreamPlayer) -> AudioStreamPlayer:
	if _act1_loop_alt_by_primary.has(primary):
		return _act1_loop_alt_by_primary[primary] as AudioStreamPlayer
	var alt := AudioStreamPlayer.new()
	alt.name = StringName("%sAct1LoopAlt" % primary.name)
	alt.bus = primary.bus
	alt.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(alt)
	_act1_loop_alt_by_primary[primary] = alt
	return alt


func _act1_loop_alt(primary: AudioStreamPlayer) -> AudioStreamPlayer:
	return _act1_loop_alt_by_primary.get(primary) as AudioStreamPlayer


func _act1_loop_leader_for(primary: AudioStreamPlayer) -> AudioStreamPlayer:
	if _act1_loop_leader.has(primary):
		var stored := _act1_loop_leader[primary] as AudioStreamPlayer
		if is_instance_valid(stored) and stored.playing:
			return stored
	for voice: AudioStreamPlayer in _act1_all_voices_for(primary):
		if voice.playing:
			return voice
	return primary


func _is_act1_pair_audible(primary: AudioStreamPlayer) -> bool:
	for voice: AudioStreamPlayer in _act1_all_voices_for(primary):
		if voice.playing:
			return true
	return false


func _act1_all_voices_for(primary: AudioStreamPlayer) -> Array[AudioStreamPlayer]:
	var voices: Array[AudioStreamPlayer] = []
	if primary == null:
		return voices
	voices.append(primary)
	var alt := _act1_loop_alt(primary)
	if alt != null:
		voices.append(alt)
	return voices


## 叠加轨只用 primary 播放；主 BGM 仍用主/备 ping-pong。
func _is_act1_overlay_primary(primary: AudioStreamPlayer) -> bool:
	return primary != null and primary != _bgm_player


func _act1_playback_voices_for(primary: AudioStreamPlayer) -> Array[AudioStreamPlayer]:
	if _is_act1_overlay_primary(primary):
		var voices: Array[AudioStreamPlayer] = []
		if primary != null:
			voices.append(primary)
		return voices
	return _act1_all_voices_for(primary)


func _stop_act1_overlay_alt_if_any(primary: AudioStreamPlayer) -> void:
	if not _is_act1_overlay_primary(primary):
		return
	var alt := _act1_loop_alt(primary)
	if alt != null and alt.playing:
		alt.stop()


func _get_act1_main_audio_phase() -> float:
	var interval := _act1_loop_interval_sec()
	if interval <= 0.0 or _bgm_player == null:
		return 0.0
	var leader := _act1_loop_leader_for(_bgm_player)
	if leader == null or not leader.playing:
		return 0.0
	return fmod(leader.get_playback_position(), interval)


func _reset_act1_loop_tracking(start_offset: float = 0.0) -> void:
	var interval := _act1_loop_interval_sec()
	_act1_last_main_phase = fmod(maxf(0.0, start_offset), interval)
	_act1_loop_armed = true


func _clear_act1_loop_tracking() -> void:
	_act1_last_main_phase = -1.0
	_act1_loop_armed = true


func _clear_act1_overlap_track(primary: AudioStreamPlayer) -> void:
	_act1_loop_leader.erase(primary)
	if primary == _bgm_player:
		_clear_act1_loop_tracking()


func _stop_act1_overlap_pair(primary: AudioStreamPlayer) -> void:
	if primary == null:
		return
	_clear_act1_overlap_track(primary)
	if primary.playing:
		primary.stop()
	var alt := _act1_loop_alt(primary)
	if alt != null and alt.playing:
		alt.stop()


func _start_act1_stream_on_player(
	primary: AudioStreamPlayer,
	stream: AudioStream,
	key: StringName,
	start_position: float,
	volume_db: float
) -> void:
	if primary == null or stream == null:
		return
	_stop_act1_overlap_pair(primary)
	var start_pos := maxf(0.0, start_position)
	if primary == _bgm_player:
		primary.stream = stream
		primary.pitch_scale = _pitch_for_bpm(key)
		primary.volume_db = volume_db
		primary.play(start_pos)
		_reset_act1_loop_tracking(start_pos)
		return
	if _is_main_bgm_audible():
		start_pos = _get_act1_main_audio_phase()
	_stop_act1_overlay_alt_if_any(primary)
	primary.stream = stream
	primary.pitch_scale = _pitch_for_bpm(key)
	primary.volume_db = volume_db
	primary.play(start_pos)
	_act1_loop_leader[primary] = primary


func _uses_native_timed_loop_for_main() -> bool:
	return _is_act3_bgm_key(_current_key)


func _process_act1_overlap_loops() -> void:
	if not _is_act1_bgm_key(_current_key):
		return
	if _uses_native_timed_loop_for_main():
		return
	if not _is_main_bgm_audible():
		_act1_last_main_phase = -1.0
		return
	_cleanup_silent_act1_voices()
	var interval := _act1_loop_interval_sec()
	var phase := _get_act1_main_audio_phase()
	if _act1_last_main_phase < 0.0:
		_act1_last_main_phase = phase
		return
	# 仅在接近循环末尾时认定相位回绕，避免解码抖动误判导致叠层错位。
	var wrapped := (
		phase + ACT1_LOOP_TRIGGER_EPS_SEC < _act1_last_main_phase
		and _act1_last_main_phase >= interval * 0.7
	)
	if wrapped:
		if _act1_loop_armed:
			_trigger_act1_synced_loops()
			_act1_loop_armed = false
	elif phase >= ACT1_LOOP_REARM_PHASE_SEC:
		_act1_loop_armed = true
	_act1_last_main_phase = phase


func _cleanup_silent_act1_voices() -> void:
	for primary: AudioStreamPlayer in _act1_all_bgm_primaries():
		if primary == null:
			continue
		for voice: AudioStreamPlayer in _act1_all_voices_for(primary):
			if not voice.playing:
				continue
			if voice.volume_db > TAPE_END_VOLUME_DB + 1.0:
				continue
			if _has_running_overlay_volume_tween(voice):
				continue
			if _is_act1_overlay_primary(primary) and voice == primary:
				if _layer_key_for_player(primary) != &"":
					continue
			voice.stop()


func _trigger_act1_synced_loops() -> void:
	var interval := _act1_loop_interval_sec()
	var now := Time.get_ticks_msec() * 0.001
	if now - _act1_last_loop_fire_time < interval * 0.85:
		return
	_act1_last_loop_fire_time = now
	var main_leader := _main_act1_loop_leader()
	if main_leader == null or not main_leader.playing:
		return
	# 仅主轨 ping-pong 叠放；叠加轨在主循环边界与每帧相位同步中重启。
	_fire_act1_loop_overlap(_bgm_player, main_leader)
	_restart_act1_overlays_at_main_loop()


func _process_act1_overlay_sync() -> void:
	if not _is_act1_bgm_key(_current_key):
		return
	if not _is_main_bgm_audible():
		return
	for primary: AudioStreamPlayer in [_battle_bgm_player, _tense_bgm_player, _tense_battle_bgm_player]:
		_purge_stale_overlay_tween_records_for_primary(primary)
	var interval := _act1_loop_interval_sec()
	if interval <= 0.0:
		return
	var main_leader := _main_act1_loop_leader()
	if main_leader == null or not main_leader.playing:
		return
	var target_phase := fmod(main_leader.get_playback_position(), interval)
	for primary: AudioStreamPlayer in [_battle_bgm_player, _tense_bgm_player, _tense_battle_bgm_player]:
		if primary == null:
			continue
		if _layer_key_for_player(primary) == &"":
			continue
		_sync_act1_overlay_primary_to_main(primary, target_phase, interval, false)


func _restart_act1_overlays_at_main_loop() -> void:
	if _uses_native_timed_loop_for_main():
		return
	var interval := _act1_loop_interval_sec()
	if interval <= 0.0:
		return
	var target_phase := _get_act1_main_audio_phase()
	for primary: AudioStreamPlayer in [_battle_bgm_player, _tense_bgm_player, _tense_battle_bgm_player]:
		if primary == null:
			continue
		if _layer_key_for_player(primary) == &"":
			continue
		_purge_stale_overlay_tween_records_for_primary(primary)
		_sync_act1_overlay_primary_to_main(primary, target_phase, interval, true)


func _main_act1_loop_leader() -> AudioStreamPlayer:
	return _act1_loop_leader_for(_bgm_player)


func _act1_phase_delta(current: float, target: float, interval: float) -> float:
	var delta := current - target
	if delta > interval * 0.5:
		delta -= interval
	elif delta < -interval * 0.5:
		delta += interval
	return delta


func _get_act1_overlay_audible_volume(primary: AudioStreamPlayer) -> float:
	for voice: AudioStreamPlayer in _act1_playback_voices_for(primary):
		if voice.playing and voice.volume_db > TAPE_END_VOLUME_DB + 1.0:
			return voice.volume_db
	if primary != null and primary.playing and primary.volume_db > TAPE_END_VOLUME_DB + 1.0:
		return primary.volume_db
	return TAPE_END_VOLUME_DB


func _sync_act1_overlay_primary_to_main(
	primary: AudioStreamPlayer,
	target_phase: float,
	interval: float,
	force_restart: bool = false
) -> void:
	var key := _layer_key_for_player(primary)
	var stream := _get_act1_stream_for_key(key)
	if stream == null:
		return
	_stop_act1_overlay_alt_if_any(primary)
	var voice := primary
	if voice.stream != stream:
		voice.stream = stream
		voice.pitch_scale = _pitch_for_bpm(key)
	if not voice.playing or force_restart:
		var volume := voice.volume_db
		if not voice.playing and volume <= TAPE_END_VOLUME_DB + 1.0:
			if _overlay_primary_has_volume_fade(primary):
				volume = TAPE_END_VOLUME_DB
			else:
				volume = BATTLE_FADE_IN_VOLUME_DB
		voice.play(target_phase)
		voice.volume_db = volume
		_act1_loop_leader[primary] = voice
		return
	var current_phase := fmod(voice.get_playback_position(), interval)
	var delta := _act1_phase_delta(current_phase, target_phase, interval)
	if absf(delta) > ACT1_OVERLAY_SYNC_THRESHOLD_SEC:
		var volume := voice.volume_db
		voice.play(target_phase)
		voice.volume_db = volume
	_act1_loop_leader[primary] = voice


func _fire_act1_loop_overlap(primary: AudioStreamPlayer, leader: AudioStreamPlayer) -> void:
	var next_player := _acquire_act1_loop_voice(primary, leader)
	if next_player.playing:
		if next_player.volume_db <= TAPE_END_VOLUME_DB + 1.0:
			next_player.stop()
		else:
			return
	_apply_act1_player_playback_state(next_player, leader)
	next_player.play(0.0)
	_act1_loop_leader[primary] = next_player


func _acquire_act1_loop_voice(primary: AudioStreamPlayer, leader: AudioStreamPlayer) -> AudioStreamPlayer:
	var alt := _ensure_act1_loop_alt(primary)
	return alt if leader == primary else primary


func _apply_act1_player_playback_state(dst: AudioStreamPlayer, src: AudioStreamPlayer) -> void:
	dst.stream = src.stream
	dst.pitch_scale = src.pitch_scale
	dst.volume_db = src.volume_db


func _act1_all_bgm_primaries() -> Array[AudioStreamPlayer]:
	return [_bgm_player, _battle_bgm_player, _tense_bgm_player, _tense_battle_bgm_player]


func _collect_audible_players_with_act1_alts() -> Array[AudioStreamPlayer]:
	var result: Array[AudioStreamPlayer] = []
	for player: AudioStreamPlayer in _act1_all_bgm_primaries():
		if player == null:
			continue
		if player.playing:
			result.append(player)
		var alt := _act1_loop_alt(player)
		if alt != null and alt.playing:
			result.append(alt)
	return result


func _bpm_for_act(act: int) -> float:
	match act:
		1:
			return ACT1_BPM
		2:
			return ACT2_BPM
		3:
			return ACT3_BPM
		_:
			return ACT1_BPM


func _resolve_loop_beats(stream: AudioStream, bpm: float, bar_beats: int = DEFAULT_BAR_BEATS) -> int:
	if stream == null or bpm <= 0.0:
		return 0
	var duration := stream.get_length()
	if duration <= 0.0:
		return 0
	var total_beats := duration * bpm / 60.0
	var bars := int(floor(total_beats / float(bar_beats)))
	return maxi(bars * bar_beats, bar_beats)


func _apply_beat_loop(
	stream: AudioStream,
	bpm: float,
	beat_count: int,
	bar_beats: int = DEFAULT_BAR_BEATS
) -> AudioStream:
	if stream == null:
		return null
	var dup := stream.duplicate()
	if dup is AudioStreamOggVorbis:
		var ogg := dup as AudioStreamOggVorbis
		ogg.loop = true
		ogg.loop_offset = 0.0
		ogg.bpm = bpm
		ogg.bar_beats = bar_beats
		ogg.beat_count = beat_count
	elif dup is AudioStreamMP3:
		var mp3 := dup as AudioStreamMP3
		mp3.loop = true
		mp3.loop_offset = 0.0
		mp3.bpm = bpm
		mp3.bar_beats = bar_beats
		mp3.beat_count = beat_count
	return dup


func _load_mp3_stream(path: String, bpm: float, beat_count: int = 0) -> AudioStreamMP3:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		push_error("MusicPlayer: failed to load audio bytes from %s" % path)
		return null
	var stream := AudioStreamMP3.new()
	stream.data = bytes
	var resolved_beats := beat_count
	if resolved_beats <= 0:
		resolved_beats = _resolve_loop_beats(stream, bpm)
	stream.loop = true
	stream.loop_offset = 0.0
	stream.bpm = bpm
	stream.beat_count = resolved_beats
	stream.bar_beats = DEFAULT_BAR_BEATS
	return stream


func _prepare_loop(stream: AudioStream, bpm: float = 0.0, beat_count: int = 0) -> AudioStream:
	if stream == null:
		return null
	var resolved_bpm := bpm
	if resolved_bpm <= 0.0:
		if stream is AudioStreamMP3:
			resolved_bpm = (stream as AudioStreamMP3).bpm
		elif stream is AudioStreamOggVorbis:
			resolved_bpm = (stream as AudioStreamOggVorbis).bpm
	if resolved_bpm <= 0.0:
		var dup := stream.duplicate()
		if dup is AudioStreamOggVorbis:
			(dup as AudioStreamOggVorbis).loop = true
		elif dup is AudioStreamMP3:
			(dup as AudioStreamMP3).loop = true
		return dup
	var resolved_beats := beat_count
	if resolved_beats <= 0:
		if stream is AudioStreamMP3 and (stream as AudioStreamMP3).beat_count > 0:
			resolved_beats = (stream as AudioStreamMP3).beat_count
		elif stream is AudioStreamOggVorbis and (stream as AudioStreamOggVorbis).beat_count > 0:
			resolved_beats = (stream as AudioStreamOggVorbis).beat_count
		else:
			resolved_beats = _resolve_loop_beats(stream, resolved_bpm)
	return _apply_beat_loop(stream, resolved_bpm, resolved_beats)


func _create_music_tween() -> Tween:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return tween


## 叠层音量 Tween 必须绑在各自 AudioStreamPlayer 上；若在 MusicPlayer 上连续 create_tween 会互相 kill。
func _create_player_volume_tween(player: AudioStreamPlayer) -> Tween:
	if player == null:
		return null
	var tween := player.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return tween


func _quiet_stop_all_act1_overlays() -> void:
	_cancel_all_overlay_volume_tweens()
	_quiet_stop_all_act1_overlays_without_cancel()


func _quiet_stop_all_act1_overlays_without_cancel() -> void:
	for player: AudioStreamPlayer in [_battle_bgm_player, _tense_battle_bgm_player, _tense_bgm_player]:
		_stop_act1_overlap_pair(player)
	if _battle_bgm_player != null:
		_battle_layer_key = &""
	if _tense_battle_bgm_player != null:
		_tense_battle_layer_key = &""
	if _tense_bgm_player != null:
		_tense_layer_key = &""


func _act1_overlap_primary_for(player: AudioStreamPlayer) -> AudioStreamPlayer:
	for primary: AudioStreamPlayer in _act1_all_bgm_primaries():
		if primary == null:
			continue
		if primary == player or _act1_loop_alt(primary) == player:
			return primary
	return player


func _tape_fade_out(duration: float = TAPE_FADE_DURATION) -> void:
	if _bgm_player == null:
		return
	var players_to_fade := _collect_audible_players_with_act1_alts()
	if players_to_fade.is_empty():
		return
	SFXPlayer.play(TAPE_STOP_SFX)
	_kill_tape_tween()
	_tape_generation += 1
	var generation := _tape_generation
	var tween := _create_music_tween()
	tween.set_parallel(true)
	for player: AudioStreamPlayer in players_to_fade:
		_cancel_overlay_volume_tween(player)
		var pitch_step := tween.tween_property(player, "pitch_scale", TAPE_END_PITCH, duration)
		pitch_step.from(player.pitch_scale).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		var volume_step := tween.tween_property(player, "volume_db", TAPE_END_VOLUME_DB, duration)
		volume_step.from(player.volume_db).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_tape_tween = tween
	await tween.finished
	if generation != _tape_generation:
		return
	_tape_tween = null


func _kill_tape_tween() -> void:
	_tape_generation += 1
	if _tape_tween != null and _tape_tween.is_valid():
		_tape_tween.kill()
	_tape_tween = null


func _cancel_tape_tween() -> void:
	_kill_tape_tween()


func _stop_immediate() -> void:
	_cancel_tape_tween()
	_cancel_all_overlay_volume_tweens()
	_stop_act1_overlap_pair(_bgm_player)
	_reset_player_audio_state()
	_quiet_stop_all_act1_overlays()


func _reset_player_audio_state() -> void:
	_bgm_player.pitch_scale = 1.0
	_bgm_player.volume_db = 0.0
