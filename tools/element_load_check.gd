extends SceneTree

func _init() -> void:
	var paths := [
		"res://common_cards/burn.tres",
		"res://statuses/thorns.tres",
		"res://statuses/darkness.tres",
		"res://statuses/thunder.tres",
		"res://enemies/elementals/fire_elemental.tres",
		"res://enemies/elementals/ice_elemental.tres",
		"res://enemies/elementals/iron_elemental.tres",
		"res://enemies/elementals/dark_elemental.tres",
		"res://enemies/elementals/electronic_elemental.tres",
		"res://battles/elementals_2.tres",
		"res://battles/elementals_3.tres",
		"res://battles/battle_stats_pool_act2.tres",
	]
	for p in paths:
		var r := ResourceLoader.load(p)
		if r == null:
			push_error("failed load " + p)
		else:
			print("loaded " + p)
	var bs := ResourceLoader.load("res://battles/elementals_2.tres") as BattleStats
	if bs != null:
		var root := bs.enemies.instantiate()
		print("elementals_2 children=", root.get_child_count())
		root.free()
	quit()