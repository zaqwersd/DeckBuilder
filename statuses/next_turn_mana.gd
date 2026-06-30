class_name NextTurnManaStatus
extends Status

## 下回合开始时额外获得的能量数（状态栏下标显示）。
var mana_to_grant: int = 0


func get_tooltip() -> String:
	return tooltip % format_counter_for_tooltip(mana_to_grant)


func apply_status(_target: Node) -> void:
	if mana_to_grant <= 0:
		status_applied.emit(self)
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		status_applied.emit(self)
		return
	var ph := tree.get_first_node_in_group("player_handler") as PlayerHandler
	if ph != null and is_instance_valid(ph.character):
		ph.character.gain_mana(mana_to_grant)
	status_applied.emit(self)
