class_name CardUpgradeUiColors
extends RefCounted

## 升级界面图例面板填充 #78909c（边框与 `card_base_stylebox.tres` 一致）
const PANEL_FILL := Color(0x78 / 255.0, 0x90 / 255.0, 0x9c / 255.0, 1.0)

const _DEFAULT_PANEL_STYLE := preload("res://scenes/card_ui/card_base_stylebox.tres") as StyleBoxFlat
## 卡面/升级说明：可通过升级改变的数值（与图例「黄色」一致）
const BB_VALUE := "#ffee58"
## 卡面/升级说明：尚未激活、需升级解锁的词条（与图例「灰色」一致；常见拼写 #b0bec5）
const BB_INACTIVE_KEYWORD := "#b0bec5"
## 卡面/升级说明：可经升级消除或弱化的负面相关数字（与图例「红色」一致）
const BB_NEGATIVE_REMOVABLE := "#f36c60"


static func color_bb_value() -> Color:
	return Color(1.0, 238.0 / 255.0, 88.0 / 255.0, 1.0)


static func color_bb_negative_removable() -> Color:
	return Color.html(BB_NEGATIVE_REMOVABLE)


static func color_bb_inactive_keyword() -> Color:
	return Color.html(BB_INACTIVE_KEYWORD)


static func style_panel_flat() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_FILL
	sb.set_corner_radius_all(0)
	var ref := _DEFAULT_PANEL_STYLE
	sb.border_color = ref.border_color
	sb.border_width_left = ref.border_width_left
	sb.border_width_top = ref.border_width_top
	sb.border_width_right = ref.border_width_right
	sb.border_width_bottom = ref.border_width_bottom
	sb.content_margin_left = 10
	sb.content_margin_top = 8
	sb.content_margin_right = 10
	sb.content_margin_bottom = 8
	return sb


static func legend_bbcode() -> String:
	return (
		"[color=%s]黄色：[/color]这个属性可以通过升级来增强。[br]"
		+ "[color=%s]红色：[/color]这个负面属性可以通过升级来减少或消除。[br]"
		+ "[color=%s]灰色：[/color]这个属性现在还未激活。通过升级以激活。"
	) % [BB_VALUE, BB_NEGATIVE_REMOVABLE, BB_INACTIVE_KEYWORD]


## 卡面 BBCode：尚未激活的词条片段（与图例「灰色」同色）。
static func bbcode_inactive_keyword(text: String) -> String:
	return "[color=%s]%s[/color]" % [BB_INACTIVE_KEYWORD, text]
