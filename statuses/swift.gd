class_name SwiftStatus
extends Status

const CARDS_TO_TRIGGER := 3

## 距迅捷触发还需打出的牌数计数（0–2 显示；到 3 触发后归零）。
var cards_toward_trigger: int = 0


func get_tooltip() -> String:
	return tooltip


func record_card_played() -> bool:
	cards_toward_trigger += 1
	status_changed.emit()
	return cards_toward_trigger >= CARDS_TO_TRIGGER


func reset_counter() -> void:
	cards_toward_trigger = 0
	status_changed.emit()


static func get_on_enemy(host: Enemy) -> SwiftStatus:
	if host == null or host.status_handler == null:
		return null
	return host.status_handler.get_status_by_id("swift") as SwiftStatus
