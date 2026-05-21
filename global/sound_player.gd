extends Node

const UI_PLAYER_PREFIX := "UI"

var _ui_hover: AudioStreamPlayer
var _ui_click: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for ch in get_children():
		if ch is AudioStreamPlayer:
			(ch as Node).process_mode = Node.PROCESS_MODE_ALWAYS
	_ui_hover = _create_ui_player("UIHover")
	_ui_click = _create_ui_player("UIClick")


func _create_ui_player(player_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = &"SFX"
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player


func _is_ui_player(player: AudioStreamPlayer) -> bool:
	return player.name.begins_with(UI_PLAYER_PREFIX)


func play(audio: AudioStream, single: bool = false) -> void:
	if not audio:
		return

	if single:
		stop()

	for player: AudioStreamPlayer in get_children():
		if not player is AudioStreamPlayer or _is_ui_player(player):
			continue
		if not player.playing:
			player.stream = audio
			player.play()
			return


func play_ui_hover(audio: AudioStream) -> void:
	_play_ui(_ui_hover, audio)


func play_ui_click(audio: AudioStream) -> void:
	_play_ui(_ui_click, audio)


func _play_ui(player: AudioStreamPlayer, audio: AudioStream) -> void:
	if not audio or player == null:
		return
	player.stream = audio
	player.play()


func stop() -> void:
	for player: AudioStreamPlayer in get_children():
		if _is_ui_player(player):
			continue
		player.stop()
