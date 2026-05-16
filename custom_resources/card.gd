class_name Card
extends Resource

enum Type {ATTACK, SKILL, POWER, STATUS}
enum Rarity {STARTER, COMMON, UNCOMMON, RARE, SPECIAL}
enum Target {SELF, SINGLE_ENEMY, ALL_ENEMIES, EVERYONE}

## 卡面数值 BBCode：战斗手牌/战斗牌堆为白底 + 仅按实际与基准比红/绿；局外列表/升级/奖励等为黄/灰/红词条色。
enum NumberBbcodeStyle {COMBAT_PILES_AND_HAND, LISTING_UPGRADE}

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

const RARITY_COLORS := {
	Card.Rarity.STARTER: Color(0.9, 0.9, 0.9),  # 初始：浅灰白色
	Card.Rarity.COMMON: Color.GRAY,
	Card.Rarity.UNCOMMON: Color(129.0 / 255.0, 212.0 / 255.0, 250.0 / 255.0),
	Card.Rarity.RARE: Color.GOLD,
	Card.Rarity.SPECIAL: Color(243.0 / 255.0, 108.0 / 255.0, 96.0 / 255.0),
}


## 卡面/提示里与「原始数值」对比后的 BBCode。战斗：白字为等；局外：等沿用默认字色，低/高用词条色。
func bbcode_for_modified_number(modified: int, base: int) -> String:
	if is_visual_number_bbcode_combat():
		if modified < base:
			return "[color=%s]%d[/color]" % [COMBAT_MODIFIED_RED, modified]
		if modified > base:
			return "[color=%s]%d[/color]" % [COMBAT_MODIFIED_GREEN, modified]
		return "[color=%s]%d[/color]" % [COMBAT_BODY_TEXT, modified]
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
## 虚无：回合结束时若仍在手牌中则消耗（不进弃牌堆），与打出消耗 exhausts 不同
@export var ethereal: bool = false
## 固有：每场战斗开始时优先入手；弃牌堆洗回牌库后与普通牌相同（见词条说明）。
@export var intrinsic: bool = false

## 各升级轨已升级次数（0=链首数值）；持久化在卡组单卡实例上。
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


func set_play_visual_start_center(center: Vector2) -> void:
	_play_visual_start_center = center


func consume_play_visual_start_center(fallback: Vector2) -> Vector2:
	var out := _play_visual_start_center if _play_visual_start_center != Vector2.INF else fallback
	_play_visual_start_center = Vector2.INF
	return out


## 为 true 时 CardUI 不在 play() 结束后播默认打出动画，由 apply_effects 自行安排顺序。
func defers_played_card_animation_to_effects() -> bool:
	return false


## 为 true 且 exhausts 时：不在 card_played 时入消耗堆，而在 play() 里 await apply_effects 全部结束后再入堆（先结算印牌等效果，再触发 card_exhausted / 心流抽牌）。
func defers_exhaust_to_end_of_play() -> bool:
	return false


func get_upgrade_steps_applied(track_id: String) -> int:
	return int(upgrade_track_steps.get(track_id, 0))


## 升级轨 id 列表；无升级则空数组。
func get_upgrade_track_ids() -> PackedStringArray:
	return PackedStringArray()


## 某轨数值链：下标 = 已应用该轨升级次数；链长 1 表示不可升。
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
	var ch := get_upgrade_chain(track_id)
	if ch.is_empty():
		return true
	return get_upgrade_steps_applied(track_id) >= ch.size() - 1


func has_any_upgradeable_track() -> bool:
	for tid: String in get_upgrade_track_ids():
		if not is_upgrade_track_maxed(tid):
			return true
	return false


## 营火/牌库：可点击的黄字数值（ugp meta）；该轨已升满则为白字。
func bbcode_upgrade_pick_digit(track_id: String, value: int) -> String:
	if is_upgrade_track_maxed(track_id):
		return str(value)
	return "[url=ugp:%s][color=%s]%d[/color][/url]" % [track_id, BB_UPGRADE_VALUE, value]


## 营火/牌库：可点击的「可弱化负面」红字数值。
func bbcode_upgrade_pick_negative_digit(track_id: String, value: int) -> String:
	if is_upgrade_track_maxed(track_id):
		return str(value)
	return "[url=ugp:%s][color=%s]%d[/color][/url]" % [track_id, BB_UPGRADE_NEGATIVE_REMOVABLE, value]


## 营火「点击词条升级」卡面描述；无可升级内容时返回空字符串。
func get_upgrade_pick_description_bbcode() -> String:
	return ""


func increment_upgrade_track(track_id: String) -> void:
	if is_upgrade_track_maxed(track_id):
		return
	var s := get_upgrade_steps_applied(track_id)
	upgrade_track_steps[track_id] = s + 1
	sync_unlocked_intrinsic_flags_from_upgrade_tracks()


## 子类：由「解锁固有」类升级轨推导 `intrinsic`；战斗开局分堆前、恢复快照后也会调用。
func sync_unlocked_intrinsic_flags_from_upgrade_tracks() -> void:
	pass


func get_total_upgrade_count() -> int:
	var n := 0
	for tid: String in get_upgrade_track_ids():
		n += get_upgrade_steps_applied(tid)
	return n


## 将所有可升级轨道一次性升至满级（无上宝石遗物使用）
func max_out_all_upgrade_tracks() -> void:
	for track_id in get_upgrade_track_ids():
		var ch := get_upgrade_chain(track_id)
		if not ch.is_empty():
			## 循环升级直到满级，确保触发子类的同步逻辑（如压剑的cost更新）
			while not is_upgrade_track_maxed(track_id):
				increment_upgrade_track(track_id)
	sync_unlocked_intrinsic_flags_from_upgrade_tracks()


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
	if cost < 0:
		return
	var spend := mana_to_spend if mana_to_spend >= 0 else cost
	Events.card_played.emit(self)
	char_stats.mana -= spend
	if plays_card_sound_on_play():
		_play_card_sound()

	var wrap_attack := type == Type.ATTACK
	if wrap_attack:
		Events.begin_attack_card_effects()
	if is_single_targeted():
		await apply_effects(targets, modifiers)
	else:
		await apply_effects(_get_targets(targets), modifiers)
	if wrap_attack:
		Events.end_attack_card_effects()
	if exhausts and defers_exhaust_to_end_of_play():
		char_stats.add_card_to_exhaust(self)


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


func get_updated_tooltip(_player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler, _combat_player: Node = null) -> String:
	return tooltip_text


## 卡面 RichTextLabel 用；默认与「更新后的提示文案」一致并居中（子类可覆盖以区分卡面/提示格式）。
func get_updated_visual_description_bbcode(
	_player_modifiers: ModifierHandler,
	_enemy_modifiers: ModifierHandler,
	_combat_player: Node = null
) -> String:
	var body := get_updated_tooltip(_player_modifiers, _enemy_modifiers, _combat_player)
	var out := body if body.contains("[center]") else "[center]%s[/center]" % body
	return _bbcode_visible_line_breaks(out)
