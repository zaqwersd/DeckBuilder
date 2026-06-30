@tool
class_name Intent
extends Resource

## 与策划一致：攻击/格挡/强化/减益/侵蚀（塞牌等污染牌库）
enum Kind { ATTACK, BLOCK, BUFF, DEBUFF, EROSION, SLEEP, STUNNED, HEAL, SUMMON }

## 非攻击格挡时用此占位，不显示数字格
const NUMBER_HIDDEN := -999999
const SLEEP_PHRASE_PART := "这个回合不会行动"
const SLEEP_PHRASE_FULL := "这个敌人这个回合不会行动。"
const STUNNED_PHRASE_PART := "这个回合不会行动"
const STUNNED_PHRASE_FULL := "这名敌人本回合无法行动。"

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


## 编辑器中 SubResource / ExtResource 常为 placeholder，不可读 display_number / current_text。
static func is_editor_placeholder(res: Resource) -> bool:
	if res == null or not Engine.is_editor_hint():
		return false
	if res.get_script() == null:
		return true
	if not res is Intent:
		return false
	return res.get(&"display_number") == null


## 编辑器预览：从 placeholder 或 SubResource 得到可写 Intent 实例。
static func editor_materialize(source: Intent) -> Intent:
	if source == null:
		return null
	if not Engine.is_editor_hint():
		return source.duplicate() as Intent
	var dup := source.duplicate(true) as Intent
	if dup != null and not is_editor_placeholder(dup):
		return dup
	var intent := Intent.new()
	var kind_val: Variant = source.get(&"kind")
	if kind_val is int:
		intent.kind = kind_val as Kind
	var icon_val: Variant = source.get(&"icon")
	if icon_val is Texture2D:
		intent.icon = icon_val
	var base_val: Variant = source.get(&"base_text")
	if base_val is String:
		intent.base_text = base_val
	return intent


static func editor_get_display_number(intent: Intent) -> int:
	if intent == null:
		return NUMBER_HIDDEN
	if Engine.is_editor_hint() and is_editor_placeholder(intent):
		return NUMBER_HIDDEN
	return intent.display_number


static func editor_get_current_text(intent: Intent) -> String:
	if intent == null:
		return ""
	if Engine.is_editor_hint() and is_editor_placeholder(intent):
		return ""
	return intent.current_text


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
		Kind.SLEEP:
			return preload("res://art/sleep.png") as Texture2D
		Kind.STUNNED:
			return preload("res://art/stunned.png") as Texture2D
		Kind.HEAL:
			return preload("res://art/heal.png") as Texture2D
		Kind.SUMMON:
			return preload("res://art/summon.png") as Texture2D
		_:
			return preload("res://art/tile_0106.png") as Texture2D


## 意图条 UI：同 `kind` 只保留第一个槽位（如双减益只显示一个减益图标）。
static func merge_by_kind_for_display(intents: Array[Intent]) -> Array[Intent]:
	var merged: Array[Intent] = []
	var seen_kinds: Dictionary = {}
	for intent in intents:
		if intent == null:
			continue
		if seen_kinds.has(intent.kind):
			continue
		seen_kinds[intent.kind] = true
		merged.append(intent)
	return merged


## 悬停说明正文（一句中文，不含 BBCode）。
static func build_intent_hover_sentence(intents: Array[Intent]) -> String:
	var display_intents := merge_by_kind_for_display(intents)
	if display_intents.size() == 1:
		var intent := display_intents[0]
		if intent != null:
			if intent.kind == Kind.STUNNED:
				return STUNNED_PHRASE_FULL
			if intent.kind == Kind.SLEEP:
				return SLEEP_PHRASE_FULL
	var parts: PackedStringArray = PackedStringArray()
	for intent in display_intents:
		if intent == null:
			continue
		if intent.kind == Kind.STUNNED:
			parts.append(STUNNED_PHRASE_PART)
			continue
		if intent.kind == Kind.SLEEP:
			parts.append(SLEEP_PHRASE_PART)
			continue
		var phrase := _phrase_for_intent_hover(intent)
		if not phrase.is_empty():
			parts.append(phrase)
	if parts.is_empty():
		return ""
	return "这名敌人将会%s。" % "并".join(parts)


## 与状态/遗物悬停框同面板样式；标题为「意图」。
static func build_intent_hover_bbcode(intents: Array[Intent]) -> String:
	var body := build_intent_hover_sentence(intents)
	if body.is_empty():
		return ""
	return TooltipBbcode.titled("意图", body)


static func _phrase_for_intent_hover(intent: Intent) -> String:
	match intent.kind:
		Kind.ATTACK:
			return _phrase_attack_intent_hover(intent)
		Kind.BLOCK:
			return "进行格挡"
		Kind.BUFF:
			return "施加正面效果"
		Kind.DEBUFF:
			return "施加负面效果"
		Kind.EROSION:
			return "对你的卡牌实施干扰"
		Kind.SLEEP:
			return ""
		Kind.STUNNED:
			return ""
		Kind.HEAL:
			return "回复生命值"
		Kind.SUMMON:
			return "召唤新的敌人"
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
