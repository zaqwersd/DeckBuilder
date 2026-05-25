class_name AlertStatus
extends Status

## 剩余睡眠回合数；每完成一次睡眠行动减 1，归零后下一敌人回合强制苏醒。
var turns_until_wake: int = 3

var _owner: Node


func get_tooltip() -> String:
	return tooltip % format_counter_for_tooltip(turns_until_wake)


func initialize_status(target: Node) -> void:
	_owner = target
	if not Events.card_played.is_connected(_on_card_played):
		Events.card_played.connect(_on_card_played)


func deactivate_status(_target: Node) -> void:
	if Events.card_played.is_connected(_on_card_played):
		Events.card_played.disconnect(_on_card_played)
	_owner = null


func tick_sleep_turn() -> void:
	turns_until_wake = maxi(0, turns_until_wake - 1)
	status_changed.emit()


func _on_card_played(card: Card) -> void:
	if card.type != Card.Type.ATTACK:
		return
	if not is_instance_valid(_owner) or not (_owner is Enemy):
		return
	var picker := (_owner as Enemy).enemy_action_picker
	if picker is MimicEnemyAI:
		(picker as MimicEnemyAI).wake_from_sleep()
