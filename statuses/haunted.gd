class_name HauntedStatus
extends Status


func get_tooltip() -> String:
	return tooltip % Status.format_tooltip_integer(stacks)


## 「幽灵」被消耗时调用：虚无消散、打出并消耗（exhaust）等；伤害 = 当前恶灵缠身层数。
static func notify_ghost_consumed(player: Player) -> void:
	if not is_instance_valid(player) or not player.status_handler:
		return
	var st := player.status_handler.get_status_by_id("haunted")
	if st == null or st.stacks <= 0:
		return
	var dmg: int = st.stacks
	player.take_damage(dmg, Modifier.Type.DMG_TAKEN)
