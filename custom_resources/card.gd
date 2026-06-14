class_name Card
extends Resource

enum Type {ATTACK, SKILL, POWER, STATUS}
enum Rarity {STARTER, COMMON, UNCOMMON, RARE, SPECIAL}
enum Target {SELF, SINGLE_ENEMY, ALL_ENEMIES, EVERYONE}

## 卡面数值 BBCode：战斗为白底+红/绿对比；局外列表为默认字色（无黄/灰/红升级提示色）。
enum NumberBbcodeStyle {COMBAT_PILES_AND_HAND, LISTING_UPGRADE, LISTING_PLAIN}

## 战斗中与基准相比偏低/偏高（与局外「可弱化负面」红同色，便于统一调色板）
const COMBAT_MODIFIED_RED := "#f36c60"
const COMBAT_MODIFIED_GREEN := "#5dff7a"
const COMBAT_BODY_TEXT := "#ffffff"

static var _visual_number_bbcode_stack: Array[NumberBbcodeStyle] = []


static func push_visual_number_bbcode_style(style: NumberBbcodeStyle) -> void:
	_visual_number_bbcode_stack.append(style)


static func pop_visual_number_bbcode_style() -> void:
	if not _visual_number_bbcode_stack.is_empty():
		_visual_number_bbcode_stack.pop_back()


static func get_current_visual_number_bbcode_style() -> NumberBbcodeStyle:
	if _visual_number_bbcode_stack.is_empty():
		return NumberBbcodeStyle.LISTING_UPGRADE
	return _visual_number_bbcode_stack[_visual_number_bbcode_stack.size() - 1]


static func is_visual_number_bbcode_combat() -> bool:
	return get_current_visual_number_bbcode_style() == NumberBbcodeStyle.COMBAT_PILES_AND_HAND


static func is_visual_number_bbcode_listing_plain() -> bool:
	return get_current_visual_number_bbcode_style() == NumberBbcodeStyle.LISTING_PLAIN

const RARITY_COLORS := {
	Card.Rarity.STARTER: Color.GRAY,
	Card.Rarity.COMMON: Color(0.9, 0.9, 0.9),
	Card.Rarity.UNCOMMON: Color(129.0 / 255.0, 212.0 / 255.0, 250.0 / 255.0),
	Card.Rarity.RARE: Color.GOLD,
	Card.Rarity.SPECIAL: Color(175.0 / 255.0, 191.0 / 255.0, 255.0 / 255.0),
}

## 不可打出（如恶灵）
const COST_UNPLAYABLE := -1
## X 费：消耗当前全部能量
const COST_X := -2


## 卡面/提示里与「原始数值」对比后的 BBCode。战斗：白字为等；局外：等沿用默认字色，低/高用词条色。
func bbcode_for_modified_number(modified: int, base: int) -> String:
	if is_visual_number_bbcode_combat():
		if modified < base:
			return "[color=%s]%d[/color]" % [COMBAT_MODIFIED_RED, modified]
		if modified > base:
			return "[color=%s]%d[/color]" % [COMBAT_MODIFIED_GREEN, modified]
		return "[color=%s]%d[/color]" % [COMBAT_BODY_TEXT, modified]
	if is_visual_number_bbcode_listing_plain():
		return str(modified)
	if modified < base:
		return "[color=%s]%d[/color]" % [CardUpgradeUiColors.BB_NEGATIVE_REMOVABLE, modified]
	if modified > base:
		return "[color=%s]%d[/color]" % [COMBAT_MODIFIED_GREEN, modified]
	return str(modified)


const BB_COLOR_UPGRADEABLE := CardUpgradeUiColors.BB_VALUE
## 与 `CardUpgradeUiColors` 图例三色一致，供子类拼装营火升级等 BBCode（黄 / 可弱化负面红 / 未激活灰）。
const BB_UPGRADE_VALUE := CardUpgradeUiColors.BB_VALUE
const BB_UPGRADE_NEGATIVE_REMOVABLE := CardUpgradeUiColors.BB_NEGATIVE_REMOVABLE
const BB_UPGRADE_INACTIVE_KEYWORD := CardUpgradeUiColors.BB_INACTIVE_KEYWORD


## modified 为战斗结算后的数；base 为当前卡面该轨「未吃修饰」的基准。局外：满级且相等为默认字色，可升级且相等为黄字。战斗：一律只按 modified 与 base 比白/红/绿。
func bbcode_for_modified_number_with_upgrade_hint(modified: int, base: int, upgrade_track_maxed: bool) -> String:
	if is_visual_number_bbcode_combat():
		if modified < base:
			return "[color=%s]%d[/color]" % [COMBAT_MODIFIED_RED, modified]
		if modified > base:
			return "[color=%s]%d[/color]" % [COMBAT_MODIFIED_GREEN, modified]
		return "[color=%s]%d[/color]" % [COMBAT_BODY_TEXT, modified]
	if is_visual_number_bbcode_listing_plain():
		return str(modified)
	if modified < base:
		return "[color=%s]%d[/color]" % [CardUpgradeUiColors.BB_NEGATIVE_REMOVABLE, modified]
	if modified > base:
		return "[color=%s]%d[/color]" % [COMBAT_MODIFIED_GREEN, modified]
	if upgrade_track_maxed:
		return str(modified)
	return "[color=%s]%d[/color]" % [BB_COLOR_UPGRADEABLE, modified]


## 左下角费用数字是否应用「可升级」黄字（费用不在描述里写时用）。
func should_visualize_cost_as_upgradeable() -> bool:
	return false


## 战斗卡面（手牌/战斗牌堆）是否在描述前显示「固有」词条行；未激活（灰）时可由子类返回 false。
func should_show_intrinsic_keyword_in_combat_description() -> bool:
	return intrinsic


@export_group("Card Attributes")
@export var id: String
@export var type: Type
@export var rarity: Rarity
@export var target: Target
@export var cost: int
@export var exhausts: bool = false
## 保留：回合结束时仍留在手牌，不进入弃牌堆
@export var retains: bool = false
## 虚无：回合结束时若仍在手牌中则消耗（不进弃牌堆），与打出消耗 exhausts 不同
@export var ethereal: bool = false
## 固有：每场战斗开始时优先入手；弃牌堆洗回牌库后与普通牌相同（见词条说明）。
@export var intrinsic: bool = false

## 是否已升级（每张卡实例最多一次）；持久化在卡组单卡实例上。
@export var is_upgraded: bool = false
## 旧档升级轨步数；读档迁移后清空，新档不再写入。
@export var upgrade_track_steps: Dictionary = {}

@export_group("Card Visuals")
## 卡面显示名称；留空则用 id 下划线转空格作为占位名
@export var card_name: String = ""
## 卡图（卡面中央插图）
@export var icon: Texture
## 卡面说明文本；支持 BBCode，留空则与 tooltip 相同（见 get_default_tooltip）
@export_multiline var description: String = ""
@export_multiline var tooltip_text: String
@export var sound: AudioStream

## 打出时由 CardUI 写入、效果协程读取；未设置时为 Vector2.INF。
var _play_visual_start_center: Vector2 = Vector2.INF
## 本次出牌快照：mana_spent、x（X 费等于 mana_spent）。再执行效果不扣费时沿用。
var _play_snapshot: Dictionary = {}


func set_play_visual_start_center(center: Vector2) -> void:
	_play_visual_start_center = center


func consume_play_visual_start_center(fallback: Vector2) -> Vector2:
	var out := _play_visual_start_center if _play_visual_start_center != Vector2.INF else fallback
	_play_visual_start_center = Vector2.INF
	return out


## 为 true 时 CardUI 不在 play() 结束后播默认打出动画，由 apply_effects 自行安排顺序。
func defers_played_card_animation_to_effects() -> bool:
	return false


## 为 true 且 exhausts 时：不在 card_played 时入消耗堆，而在 play() 里 await apply_effects 全部结束后再入堆（先结算印牌等效果，再触发 card_exhausted）。
func defers_exhaust_to_end_of_play() -> bool:
	return false


## 子类：该卡是否定义了可升级内容（默认：存在升级轨即视为可升）。
func defines_upgrade() -> bool:
	return not get_upgrade_track_ids().is_empty()


func can_be_upgraded() -> bool:
	return not is_upgraded and defines_upgrade()


## 应用固定的一次性升级（营火、奖励、战斗效果等统一入口）。
func apply_upgrade() -> void:
	if not can_be_upgraded():
		return
	is_upgraded = true
	upgrade_track_steps.clear()
	_apply_upgraded_state()


## 子类：升级后同步 cost / intrinsic / exhausts 等；默认同步固有类升级轨。
func _apply_upgraded_state() -> void:
	sync_upgraded_flags()


## 战斗开局分堆前、恢复快照后调用，与旧 sync_unlocked_intrinsic_flags_from_upgrade_tracks 等价。
func sync_upgraded_flags() -> void:
	sync_unlocked_intrinsic_flags_from_upgrade_tracks()


## 子类：由「解锁固有」类升级轨推导 `intrinsic` 等。
func sync_unlocked_intrinsic_flags_from_upgrade_tracks() -> void:
	pass


## 旧档：任意轨曾升过级 → 视为已升级并套用固定升级后数值。
func migrate_from_upgrade_tracks() -> void:
	if upgrade_track_steps.is_empty():
		return
	is_upgraded = true
	upgrade_track_steps.clear()
	_apply_upgraded_state()


func get_upgrade_steps_applied(track_id: String) -> int:
	if is_upgraded:
		var ch_up := get_upgrade_chain(track_id)
		if ch_up.is_empty():
			return 0
		return mini(1, ch_up.size() - 1)
	return int(upgrade_track_steps.get(track_id, 0))


## 升级轨 id 列表；无升级则空数组。
func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray()


## 某轨数值链：下标 0=未升级，1=升级后（固定一档）；链长 1 表示该轨不参与升级。
func get_upgrade_chain(track_id: String) -> PackedInt32Array:
	return PackedInt32Array()


func get_upgrade_value_at(track_id: String, steps_override: int = -1) -> int:
	var steps := steps_override if steps_override >= 0 else get_upgrade_steps_applied(track_id)
	var ch := get_upgrade_chain(track_id)
	if ch.is_empty():
		return 0
	var idx := clampi(steps, 0, ch.size() - 1)
	return ch[idx]


func is_upgrade_track_maxed(track_id: String) -> bool:
	if is_upgraded:
		return true
	var ch := get_upgrade_chain(track_id)
	if ch.is_empty():
		return true
	return get_upgrade_steps_applied(track_id) >= ch.size() - 1


func has_any_upgradeable_track() -> bool:
	return can_be_upgraded()


func get_total_upgrade_count() -> int:
	return 1 if is_upgraded else 0


## 局外列表数值；LISTING_PLAIN 与已升级均为默认字色。
func bbcode_upgrade_pick_digit(_track_id: String, value: int) -> String:
	if is_upgraded or is_visual_number_bbcode_listing_plain():
		return str(value)
	return "[color=%s]%d[/color]" % [BB_UPGRADE_VALUE, value]


## 局外列表负面数值；LISTING_PLAIN 与已升级均为默认字色。
func bbcode_upgrade_pick_negative_digit(_track_id: String, value: int) -> String:
	if is_upgraded or is_visual_number_bbcode_listing_plain():
		return str(value)
	return "[color=%s]%d[/color]" % [BB_UPGRADE_NEGATIVE_REMOVABLE, value]


## 营火升级界面已废弃；子类可保留供 get_default_tooltip 使用。
func get_upgrade_pick_description_bbcode() -> String:
	return ""


## 兼容旧调用：等价于 apply_upgrade()。
func increment_upgrade_track(_track_id: String) -> void:
	apply_upgrade()


## 兼容旧调用：等价于 apply_upgrade()。
func max_out_all_upgrade_tracks() -> void:
	apply_upgrade()


func is_unplayable() -> bool:
	return cost == COST_UNPLAYABLE


## 除费用外的出牌条件；子类可覆盖（如低血才能打出）。
func meets_play_requirements(char_stats: CharacterStats) -> bool:
	return true


## 出牌条件未满足时仍正常显示、可拖出；松手由 can_play_card 拦截（如不屈）。
func allows_hand_drag_when_play_requirements_unmet() -> bool:
	return false


func is_x_cost() -> bool:
	return cost == COST_X


func get_base_mana_cost() -> int:
	return cost


func _begin_play_snapshot(mana_spent: int) -> void:
	_play_snapshot = {
		"mana_spent": mana_spent,
		"x": mana_spent if is_x_cost() else 0,
	}


func get_play_x() -> int:
	return int(_play_snapshot.get("x", 0))


func get_play_mana_spent() -> int:
	return int(_play_snapshot.get("mana_spent", 0))


func has_play_snapshot() -> bool:
	return not _play_snapshot.is_empty()


func is_single_targeted() -> bool:
	return target == Target.SINGLE_ENEMY


func get_effect_targets(selected: Array[Node]) -> Array[Node]:
	if is_single_targeted():
		return selected.duplicate()
	return _get_targets(selected)


func _get_targets(targets: Array[Node]) -> Array[Node]:
	if not targets:
		return []

	var tree := targets[0].get_tree()

	match target:
		Target.SELF:
			return tree.get_nodes_in_group("player")
		Target.ALL_ENEMIES:
			return tree.get_nodes_in_group("enemies")
		Target.EVERYONE:
			return tree.get_nodes_in_group("player") + tree.get_nodes_in_group("enemies")
		_:
			return []


## 是否在 Card.play() 时播放卡面 @export sound。攻击牌、格挡技能等由 Damage/Block 效果播放。
func plays_card_sound_on_play() -> bool:
	return type == Type.POWER


func _play_card_sound() -> void:
	if sound:
		SFXPlayer.play(sound)


func play(targets: Array[Node], char_stats: CharacterStats, modifiers: ModifierHandler, mana_to_spend: int = -1) -> void:
	if is_unplayable():
		return
	var spend := mana_to_spend if mana_to_spend >= 0 else get_base_mana_cost()
	if is_x_cost() and mana_to_spend < 0:
		spend = char_stats.mana
	_begin_play_snapshot(spend)
	Events.card_played.emit(self)
	char_stats.mana -= spend
	if plays_card_sound_on_play():
		_play_card_sound()

	if is_single_targeted():
		await _execute_card_effects(targets, modifiers)
	else:
		await _execute_card_effects(_get_targets(targets), modifiers)

	# 消耗牌：延迟进入消耗堆
	if exhausts and defers_exhaust_to_end_of_play():
		char_stats.add_card_to_exhaust(self)

	# 普通技能/攻击牌：延迟进入弃牌堆（在 apply_effects 完成后）
	# 避免卡牌在效果执行期间被洗回抽牌堆
	if not exhausts and not (type == Type.POWER) and not (type == Type.STATUS):
		# 检查是否已经在弃牌堆（避免重复添加）
		if not char_stats.discard.cards.has(self):
			char_stats.discard.add_card(self)

	Events.card_play_finished.emit(self)


func _execute_card_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
	var wrap_attack := type == Type.ATTACK
	if wrap_attack:
		Events.begin_attack_card_effects()
	await apply_effects(targets, modifiers)
	if wrap_attack:
		Events.end_attack_card_effects()


func replay_effects_without_payment(targets: Array[Node], modifiers: ModifierHandler) -> void:
	if not has_play_snapshot():
		return
	if plays_card_sound_on_play():
		_play_card_sound()
	if is_single_targeted():
		await _execute_card_effects(targets, modifiers)
	else:
		await _execute_card_effects(_get_targets(targets), modifiers)
	## 故障机器等无费重放：效果结算完毕，与正常 play() 一样计入迅捷等「打牌完成」逻辑。
	Events.card_play_finished.emit(self)


func apply_effects(_targets: Array[Node], _modifiers: ModifierHandler) -> void:
	pass


func get_display_name() -> String:
	var n := card_name.strip_edges()
	if not n.is_empty():
		return n
	return id.replace("_", " ")


func get_default_tooltip() -> String:
	return tooltip_text


func get_visual_description_bbcode() -> String:
	var d := description.strip_edges()
	var body: String
	if d.is_empty():
		body = get_default_tooltip()
	elif d.contains("[center]"):
		body = d
	else:
		body = "[center]%s[/center]" % d
	return _bbcode_visible_line_breaks(body)


func _bbcode_visible_line_breaks(text: String) -> String:
	# RichTextLabel + BBCode 下，[center] 等块里字面换行常被当成空格；统一成 [br] 才稳定换行。
	return text.replace("\n", "[br]")


## 战斗预览：当前瞄准/悬停到的单体敌人（由 CardUI 写入，供 `compute_attack_damage_dealt` 按敌人分别结算）。
static var preview_target_enemy: Node = null


func get_updated_tooltip(_player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler, _combat_player: Node = null) -> String:
	return tooltip_text


## 玩家打出格挡牌时的实际格挡（含敏捷、脆弱等）；`combat_player` 为战斗中的 Player 节点。
func effective_block_from_card_play(base: int, combat_player: Node = null) -> int:
	return BlockEffect.compute_card_block_amount(base, combat_player)


## 攻击牌：玩家侧伤害（力量、虚弱等），不含敌人易伤（由 take_damage 结算）。
func resolve_attack_damage_dealt(
	intrinsic: int,
	player_modifiers: ModifierHandler,
	combat_player: Node = null
) -> int:
	if type != Type.ATTACK:
		return intrinsic
	var v := intrinsic
	if player_modifiers:
		v = player_modifiers.get_modified_value(v, Modifier.Type.DMG_DEALT)
	return WeakStatus.apply_to_attack_damage(v, combat_player)


static func resolve_preview_combat_player(
	combat_player: Node,
	player_modifiers: ModifierHandler
) -> Player:
	if combat_player is Player:
		return combat_player as Player
	if player_modifiers != null and is_instance_valid(player_modifiers):
		var owner := player_modifiers.get_parent()
		if owner is Player:
			return owner as Player
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		var players := tree.get_nodes_in_group("battle_player")
		if not players.is_empty() and players[0] is Player:
			return players[0] as Player
	return null


static func resolve_preview_target_enemy(
	target_enemy: Node,
	enemy_modifiers: ModifierHandler
) -> Node:
	if is_instance_valid(target_enemy):
		return target_enemy
	if is_instance_valid(preview_target_enemy):
		return preview_target_enemy
	return MaliceStatus.resolve_enemy_from_modifier_handler(enemy_modifiers)


## 攻击牌：卡面/提示完整预览（含敌人易伤、杀气、巨剑等）。仅在有瞄准敌人时套用该敌人的易伤/杀气。
func compute_attack_damage_dealt(
	intrinsic: int,
	player_modifiers: ModifierHandler,
	enemy_modifiers: ModifierHandler,
	combat_player: Node = null,
	target_enemy: Node = null
) -> int:
	var v := resolve_attack_damage_dealt(intrinsic, player_modifiers, combat_player)
	var preview_player := resolve_preview_combat_player(combat_player, player_modifiers)
	var enemy := resolve_preview_target_enemy(target_enemy, enemy_modifiers)
	if not is_instance_valid(enemy):
		return OverwhelmingStatus.apply_to_attack_card_preview_damage(preview_player, v, type)
	var combined := MaliceStatus.get_combined_vulnerable_percent(preview_player, enemy)
	if combined >= 0.0:
		v = maxi(0, ceili(float(v) * (1.0 + combined)))
	elif enemy_modifiers:
		v = enemy_modifiers.get_modified_value(v, Modifier.Type.DMG_TAKEN)
	return OverwhelmingStatus.apply_to_attack_card_preview_damage(preview_player, v, type)


func _get_combat_player_for_effects(targets: Array[Node]) -> Node:
	for t: Node in targets:
		if t is Player:
			return t
	if targets.is_empty() or not is_instance_valid(targets[0]) or not targets[0].is_inside_tree():
		return null
	var tree := targets[0].get_tree()
	if tree == null:
		return null
	var players := tree.get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0]


## 战斗中描述正文下方追加的实际结算预览（如「造成 m 点伤害 n 次」）；默认无。
func get_combat_effect_summary_bbcode(
	_player_modifiers: ModifierHandler,
	_enemy_modifiers: ModifierHandler,
	_combat_player: Node = null
) -> String:
	return ""


## 卡面 RichTextLabel 用；默认与「更新后的提示文案」一致并居中（子类可覆盖以区分卡面/提示格式）。
func get_updated_visual_description_bbcode(
	_player_modifiers: ModifierHandler,
	_enemy_modifiers: ModifierHandler,
	_combat_player: Node = null
) -> String:
	var body := get_updated_tooltip(_player_modifiers, _enemy_modifiers, _combat_player)
	var out := body if body.contains("[center]") else "[center]%s[/center]" % body
	return _bbcode_visible_line_breaks(out)
