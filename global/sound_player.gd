extends Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for ch in get_children():
		if ch is Node:
			(ch as Node).process_mode = Node.PROCESS_MODE_ALWAYS


func play(audio: AudioStream, single=false) -> void:
	if not audio:
		return
		
	if single:
		stop()

	for player: AudioStreamPlayer in get_children():
		if not player.playing:
			player.stream = audio
			player.play()
			break


func stop() -> void:
	for player: AudioStreamPlayer in get_children():
		player.stop()
