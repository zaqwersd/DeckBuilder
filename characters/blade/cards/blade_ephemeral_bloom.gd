extends Card

## 昙花一现 - 2费稀有技能（可升级至1费）
## 虚无。本回合获得9（12/17）点力量。


## 升级轨道：费用 2->1，力量 9->12->17
func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray(["cost", "power_value"])


func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	match track_id:
		"cost":
			return PackedInt32Array([2, 1])  ## 2费 -> 1费
		"power_value":
			return PackedInt32Array([9, 12, 17])
		_:
			return PackedInt32Array()


## 获取当前费用值
func _intrinsic_cost() -> int:
	return get_upgrade_value_at("cost")


## 告诉UI费用可升级（显示黄色）
func should_visualize_cost_as_upgradeable() -> bool:
	var ch := get_upgrade_chain("cost")
	if ch.is_empty():
		return false
	return not is_upgrade_track_maxed("cost")


## 升级时同步更新费用
func increment_upgrade_track(track_id: String) -> void:
	super.increment_upgrade_track(track_id)
	if track_id == "cost":
		cost = _intrinsic_cost()


func _get_power_value() -> int:
	return get_upgrade_value_at("power_value")


func _power_chain_first() -> int:
	var ch := get_upgrade_chain("power_value")
	if ch.is_empty():
		return get_upgrade_value_at("power_value")
	return int(ch[0])


## 卡面/提示：只显示当前力量值；力量轨满级为白字，未满级按与链首比较着色。
func _power_current_colored_bbcode() -> String:
	var cur := get_upgrade_value_at("power_value")
	var first := _power_chain_first()
	var mx := is_upgrade_track_maxed("power_value")
	var combat := Card.is_visual_number_bbcode_combat()

	if mx:
		if combat:
			return "[color=%s]%d[/color]" % [Card.COMBAT_BODY_TEXT, cur]
		return str(cur)

	if cur < first:
		if combat:
			return "[color=%s]%d[/color]" % [Card.COMBAT_MODIFIED_RED, cur]
		return "[color=%s]%d[/color]" % [CardUpgradeUiColors.BB_NEGATIVE_REMOVABLE, cur]
	if cur > first:
		return "[color=%s]%d[/color]" % [Card.BB_COLOR_UPGRADEABLE, cur]
	if combat:
		return "[color=%s]%d[/color]" % [Card.COMBAT_BODY_TEXT, cur]
	return "[color=%s]%d[/color]" % [Card.BB_COLOR_UPGRADEABLE, cur]


func _power_line_listing_bbcode() -> String:
	return "本回合获得%s点力量" % _power_current_colored_bbcode()


func _power_line_upgrade_pick_bbcode() -> String:
	if is_upgrade_track_maxed("power_value"):
		var v := get_upgrade_value_at("power_value")
		return "本回合获得[color=%s]%d[/color]点力量" % [Card.COMBAT_BODY_TEXT, v]
	return "本回合获得%s点力量" % bbcode_upgrade_pick_digit("power_value", get_upgrade_value_at("power_value"))


## 营火升级选择描述
func get_upgrade_pick_description_bbcode() -> String:
	return "[center]虚无。[br]%s。[/center]" % _power_line_upgrade_pick_bbcode()


## 默认提示文本（牌库列表/营火）
func get_default_tooltip() -> String:
	return "[center]虚无。[br]%s。[/center]" % _power_line_listing_bbcode()


## 更新的提示文本
func get_updated_tooltip(
	_player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler, _combat_player: Node = null
) -> String:
	var intrinsic := _get_power_value()
	var mx := is_upgrade_track_maxed("power_value")
	var power_str := bbcode_for_modified_number_with_upgrade_hint(intrinsic, intrinsic, mx)
	return "[center]虚无。[br]本回合获得%s点力量。[/center]" % power_str


## 卡面描述
func get_visual_description_bbcode() -> String:
	return "[center]虚无。[br]%s。[/center]" % _power_line_listing_bbcode()


## 战斗场景更新的卡面描述
func get_updated_visual_description_bbcode(
	_player_modifiers: ModifierHandler,
	_enemy_modifiers: ModifierHandler,
	_combat_player: Node = null
) -> String:
	return get_visual_description_bbcode()


## 虚无牌仍播放音效
func plays_card_sound_on_play() -> bool:
	return true


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	if targets.is_empty():
		return

	var player := targets[0]
	var status_handler: StatusHandler = player.get("status_handler")
	if status_handler == null:
		return

	var power_value := _get_power_value()

	## 1. 添加/增加力量状态
	var muscle_status := preload("res://statuses/strength.tres").duplicate(true) as MuscleStatus
	if muscle_status:
		muscle_status.stacks = power_value
		status_handler.add_status(muscle_status)

	## 2. 添加临时力量状态
	var ephemeral_status := preload("res://statuses/temp_strength.tres").duplicate(true) as EphemeralMuscleStatus
	if ephemeral_status:
		ephemeral_status.stacks = power_value
		status_handler.add_status(ephemeral_status)
