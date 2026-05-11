class_name Card
extends Resource

enum Type {ATTACK, SKILL, POWER, STATUS}
enum Rarity {COMMON, UNCOMMON, RARE}
enum Target {SELF, SINGLE_ENEMY, ALL_ENEMIES, EVERYONE}

const RARITY_COLORS := {
	Card.Rarity.COMMON: Color.GRAY,
	Card.Rarity.UNCOMMON: Color.CORNFLOWER_BLUE,
	Card.Rarity.RARE: Color.GOLD,
}


## 卡面/提示里与「原始数值」对比后的 BBCode：相等白、低红、高绿（伤害与格挡通用）。子类在 get_updated_tooltip 中直接调用即可。
func bbcode_for_modified_number(modified: int, base: int) -> String:
	if modified < base:
		return "[color=#ff6b6b]%d[/color]" % modified
	if modified > base:
		return "[color=#5dff7a]%d[/color]" % modified
	return "[color=#ffffff]%d[/color]" % modified


@export_group("Card Attributes")
@export var id: String
@export var type: Type
@export var rarity: Rarity
@export var target: Target
@export var cost: int
@export var exhausts: bool = false
## 虚无：回合结束时若仍在手牌中则消耗（不进弃牌堆），与打出消耗 exhausts 不同
@export var ethereal: bool = false

@export_group("Card Visuals")
## 卡面显示名称；留空则用 id 下划线转空格作为占位名
@export var card_name: String = ""
## 卡图（卡面中央插图）
@export var icon: Texture
## 卡面说明文本；支持 BBCode，留空则与 tooltip 相同（见 get_default_tooltip）
@export_multiline var description: String = ""
@export_multiline var tooltip_text: String
@export var sound: AudioStream


func is_single_targeted() -> bool:
	return target == Target.SINGLE_ENEMY


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


func play(targets: Array[Node], char_stats: CharacterStats, modifiers: ModifierHandler) -> void:
	if cost < 0:
		return
	Events.card_played.emit(self)
	char_stats.mana -= cost

	if is_single_targeted():
		apply_effects(targets, modifiers)
	else:
		apply_effects(_get_targets(targets), modifiers)


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


func get_updated_tooltip(_player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler) -> String:
	return tooltip_text


## 卡面 RichTextLabel 用；默认与「更新后的提示文案」一致并居中（子类可覆盖以区分卡面/提示格式）。
func get_updated_visual_description_bbcode(
	_player_modifiers: ModifierHandler,
	_enemy_modifiers: ModifierHandler
) -> String:
	var body := get_updated_tooltip(_player_modifiers, _enemy_modifiers)
	var out := body if body.contains("[center]") else "[center]%s[/center]" % body
	return _bbcode_visible_line_breaks(out)
