class_name StatsUI
extends HBoxContainer

@onready var health: HealthUI = $Health


func update_stats(stats: Stats) -> void:
	health.update_stats(stats)
	health.visible = stats.health > 0
