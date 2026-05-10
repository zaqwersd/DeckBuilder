class_name Card
extends Resource

enum Type {ATTACK, SKILL, POWER}
enum Rarity {COMMON, UNCOMMON, RARE}
enum Target {SELF, SINGLE_ENEMY, ALL_ENEMIES, EVERYONE}

const RARITY_COLORS := {
	Card.Rarity.COMMON: Color.GRAY,
	Card.Rarity.UNCOMMON: Color.CORNFLOWER_BLUE,
	Card.Rarity.RARE: Color.GOLD,
}

@export_group("Card Attributes")
@export var id: String
@export var type: Type
@export var rarity: Rarity
@export var target: Target
@export var cost: int
@export var exhausts: bool = false

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
	if d.is_empty():
		return get_default_tooltip()
	if d.contains("[center]"):
		return d
	return "[center]%s[/center]" % d


func get_updated_tooltip(_player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler) -> String:
	return tooltip_text


## 卡面 RichTextLabel 用；默认与「更新后的提示文案」一致并居中（子类可覆盖以区分卡面/提示格式）。
func get_updated_visual_description_bbcode(
	_player_modifiers: ModifierHandler,
	_enemy_modifiers: ModifierHandler
) -> String:
	var body := get_updated_tooltip(_player_modifiers, _enemy_modifiers)
	if body.contains("[center]"):
		return body
	return "[center]%s[/center]" % body
