class_name Intent
extends Resource

## 与策划一致：攻击/格挡/强化/减益/侵蚀（塞牌等污染牌库）
enum Kind { ATTACK, BLOCK, BUFF, DEBUFF, EROSION }

## 非攻击格挡时用此占位，不显示数字格
const NUMBER_HIDDEN := -999999

@export var kind: Kind = Kind.ATTACK
## 留空则使用 `kind` 的默认占位图标（可在工程中替换默认图路径）
@export var icon: Texture2D
## 非攻击：可在 `update_intent_text` 里写入 current_text；攻击建议用 `set_attack_segments_display`
@export var base_text: String = ""

var current_text: String = ""
## 仅攻击意图会显示数字；格挡只显示图标（仍可由脚本写入 display_number 供其它逻辑用）
var display_number: int = NUMBER_HIDDEN


## 攻击意图：`IntentSlot` 中单段只显示伤害数字；多段显示「每段伤害×段数」（如 8×2）。
func set_attack_segments_display(per_hit: int, segment_count: int = 1) -> void:
	var hits: int = maxi(1, segment_count)
	if hits <= 1:
		current_text = ""
		display_number = per_hit
	else:
		display_number = NUMBER_HIDDEN
		current_text = "%d×%d" % [per_hit, hits]


## 与 `IntentSlot` 一致：仅攻击会在图标旁显示文案/数字；其它种类只显示图标。
func shows_numeric_label() -> bool:
	return kind == Kind.ATTACK


func get_display_icon() -> Texture2D:
	# 不要用 `if icon:`：未赋值的 @export Texture2D 在部分加载顺序下可能非 null 但无效；
	# 损坏/丢失的引用也可能有「空尺寸」，应回退到 kind 默认图。
	if icon != null:
		if icon.get_width() > 0 and icon.get_height() > 0:
			return icon
	return _default_icon_for_kind(kind)


static func _default_icon_for_kind(k: Kind) -> Texture2D:
	match k:
		Kind.ATTACK:
			return preload("res://art/attack.png") as Texture2D
		Kind.BLOCK:
			return preload("res://art/defend.png") as Texture2D
		Kind.BUFF:
			return preload("res://art/buff.png") as Texture2D
		Kind.DEBUFF:
			return preload("res://art/debuff.png") as Texture2D
		Kind.EROSION:
			return preload("res://art/erosion.png") as Texture2D
		_:
			return preload("res://art/tile_0106.png") as Texture2D


## 悬停说明正文（一句中文，不含 BBCode）。
static func build_intent_hover_sentence(intents: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for it in intents:
		if it == null or not (it is Intent):
			continue
		var phrase := _phrase_for_intent_hover(it as Intent)
		if not phrase.is_empty():
			parts.append(phrase)
	if parts.is_empty():
		return ""
	return "这名敌人将会%s。" % "并".join(parts)


## 与状态/遗物悬停框同面板样式，但无标题行。
static func build_intent_hover_bbcode(intents: Array) -> String:
	return build_intent_hover_sentence(intents)


static func _phrase_for_intent_hover(intent: Intent) -> String:
	match intent.kind:
		Kind.ATTACK:
			return _phrase_attack_intent_hover(intent)
		Kind.BLOCK:
			return "进行格挡"
		Kind.BUFF:
			return "给自己施加正面效果"
		Kind.DEBUFF:
			return "对你施加负面效果"
		Kind.EROSION:
			return "对你的卡牌实施干扰"
		_:
			return ""


static func _phrase_attack_intent_hover(intent: Intent) -> String:
	var raw := intent.current_text.strip_edges()
	if not raw.is_empty():
		var sep := ""
		if raw.contains("×"):
			sep = "×"
		elif raw.contains("X"):
			sep = "X"
		elif raw.contains("x"):
			sep = "x"
		if not sep.is_empty():
			var bits := raw.split(sep, false)
			if bits.size() >= 2:
				var per := bits[0].strip_edges()
				var n2 := bits[1].strip_edges().to_int()
				if n2 > 1:
					return "对你造成%s点伤害%d次" % [per, n2]
	if intent.display_number != NUMBER_HIDDEN:
		return "对你造成%d点伤害" % intent.display_number
	if not raw.is_empty():
		return "对你造成%s点伤害" % raw
	return "对你发动攻击"
