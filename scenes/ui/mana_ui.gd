class_name ManaUI
extends Panel

## 与剑客 `blade.tres` 的 `relic_match_id` 一致；能量条底板用同色主题
const BLADE_MANA_PANEL_BG := Color(0.0 / 255.0, 150.0 / 255.0, 136.0 / 255.0, 1.0)

@export var char_stats: CharacterStats : set = _set_char_stats

@onready var mana_label: Label = $ManaLabel


func _set_char_stats(value: CharacterStats) -> void:
	char_stats = value
	
	if not char_stats.stats_changed.is_connected(_on_stats_changed):
		char_stats.stats_changed.connect(_on_stats_changed)

	if not is_node_ready():
		await ready

	_apply_mana_panel_theme()
	_on_stats_changed()


func _apply_mana_panel_theme() -> void:
	if char_stats != null and char_stats.relic_match_id.strip_edges().to_lower() == "blade":
		var sb := StyleBoxFlat.new()
		sb.bg_color = BLADE_MANA_PANEL_BG
		sb.set_border_width_all(4)
		sb.border_color = Color(0.701961, 0.701961, 0.701961, 1)
		add_theme_stylebox_override("panel", sb)
	else:
		remove_theme_stylebox_override("panel")


func _on_stats_changed() -> void:
	mana_label.text = "%s/%s" % [char_stats.mana, char_stats.max_mana]
