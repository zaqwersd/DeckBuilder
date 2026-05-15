class_name FlowStateStatus
extends Status

## 心流：每次有牌进入消耗堆时，按激活轨抽牌 / 获得能量。
var draw_on_exhaust: int = 0
var mana_on_exhaust: int = 0


func get_tooltip() -> String:
	var parts: PackedStringArray = PackedStringArray()
	if draw_on_exhaust > 0:
		parts.append(
			"抽%s张牌" % Status.format_tooltip_integer(draw_on_exhaust)
		)
	if mana_on_exhaust > 0:
		parts.append(
			"获得%s点能量" % Status.format_tooltip_integer(mana_on_exhaust)
		)
	if parts.is_empty():
		return "你尚未掌握这个能力。"
	return "每当有牌被消耗时，%s。" % "、".join(parts)


func initialize_status(target: Node) -> void:
	if not Events.card_exhausted.is_connected(_on_card_exhausted):
		Events.card_exhausted.connect(_on_card_exhausted)


func apply_status(_target: Node) -> void:
	status_applied.emit(self)


func _on_card_exhausted(_card: Card) -> void:
	if draw_on_exhaust <= 0 and mana_on_exhaust <= 0:
		return
	if Events.is_combat_ended():
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var ph := tree.get_first_node_in_group("player_handler") as PlayerHandler
	if ph == null:
		return
	if ph.is_deferring_flow_for_end_turn_discard():
		ph.accumulate_end_turn_flow_from_exhaust(draw_on_exhaust, mana_on_exhaust)
		return
	if draw_on_exhaust > 0:
		ph.draw_cards(draw_on_exhaust)
	if mana_on_exhaust > 0 and is_instance_valid(ph.character):
		ph.character.mana += mana_on_exhaust
