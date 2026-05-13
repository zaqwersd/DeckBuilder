class_name EventRoomButtonAwaitExit
extends EventRoomButton

## 先 await 回调（用于需动画/协程的选项），再退出事件房；同步回调也可 await。

func _on_pressed() -> void:
	if event_button_callback.is_valid():
		await event_button_callback.call()
	Events.event_room_exited.emit()
