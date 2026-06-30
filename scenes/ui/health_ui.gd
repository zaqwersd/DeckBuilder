class_name HealthUI
extends HBoxContainer

@export var show_max_hp: bool


func _resolve_health_label() -> Label:
	if has_node("HealthLabel"):
		return get_node("HealthLabel") as Label
	if has_node("BarHost/HealthLabel"):
		return get_node("BarHost/HealthLabel") as Label
	return null


func _resolve_max_health_label() -> Label:
	if has_node("MaxHealthLabel"):
		return get_node("MaxHealthLabel") as Label
	if has_node("BarHost/MaxHealthLabel"):
		return get_node("BarHost/MaxHealthLabel") as Label
	return null


func update_stats(stats: Stats) -> void:
	if stats == null:
		return
	var hl := _resolve_health_label()
	if hl == null:
		return
	hl.text = str(stats.health)
	var max_lbl := _resolve_max_health_label()
	if max_lbl != null:
		max_lbl.text = "/%s" % str(stats.max_health)
		max_lbl.visible = show_max_hp
