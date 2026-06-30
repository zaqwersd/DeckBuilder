class_name MapRoomTooltipUtil
extends RefCounted

const BOSS_MAP_ICONS := preload("res://global/boss_map_icon_util.gd")


static func get_tooltip_bbcode(room: Room) -> String:
	if room == null:
		return ""
	match _display_type(room):
		Room.Type.MONSTER:
			return TooltipBbcode.titled("普通战斗", "你将在这里遭遇一些普通的敌人。")
		Room.Type.ELITE:
			return TooltipBbcode.titled("精英", "你将在这里遭遇一些强大的敌人。如果你击败了它们，也许能得到丰厚的奖励。")
		Room.Type.CAMPFIRE:
			return TooltipBbcode.titled("营火", "你可以在这里休息，升级卡牌，或是做些别的事。")
		Room.Type.SHOP:
			return TooltipBbcode.titled("商店", "你可以在这里花钱买一些东西。")
		Room.Type.UNKNOWN:
			return TooltipBbcode.titled("未知", "你不知道这里有什么。")
		Room.Type.BOSS:
			return _boss_tooltip_bbcode(room)
		Room.Type.TREASURE:
			return TooltipBbcode.titled("宝箱", "你将在这里获得一件遗物。")
		_:
			return ""


static func _display_type(room: Room) -> Room.Type:
	if room.type == Room.Type.EVENT:
		return Room.Type.UNKNOWN
	return room.type


static func _boss_tooltip_bbcode(room: Room) -> String:
	var boss_name := BOSS_MAP_ICONS.get_boss_display_name(room.battle_stats)
	var safe := TooltipBbcode.escape_brackets(boss_name)
	var body := "这是[color=%s][b]%s[/b][/color]，一个强大的敌人。你将在本幕的末尾与其战斗。" % [
		TooltipBbcode.TITLE_COLOR,
		safe,
	]
	return TooltipBbcode.titled("Boss", body)
