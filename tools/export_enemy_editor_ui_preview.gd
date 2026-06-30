extends SceneTree

const ENEMY_SCENES: Array[String] = [
	"res://enemies/bat/bat_enemy.tscn",
	"res://enemies/rat/rat_enemy.tscn",
	"res://enemies/crab/crab_enemy.tscn",
	"res://enemies/spider/spider_enemy.tscn",
	"res://enemies/mimic/mimic_enemy.tscn",
	"res://enemies/bone_chewer/bone_chewer_enemy.tscn",
	"res://enemies/pilgrim/pilgrim_enemy.tscn",
	"res://enemies/igneous_burster/igneous_burster_enemy.tscn",
	"res://enemies/little_skelton/little_skelton_enemy.tscn",
	"res://enemies/shell_mech/shell_mech_enemy.tscn",
	"res://enemies/ghost_summoner/ghost_summoner_enemy.tscn",
	"res://enemies/ghost_summoner/spook_enemy.tscn",
	"res://enemies/evil_spirit/evil_spirit_enemy.tscn",
	"res://enemies/heaven_guardian/heaven_guardian_enemy.tscn",
	"res://enemies/shadow_samurai/shadow_samurai_enemy.tscn",
	"res://enemies/water_monster/water_monster_enemy.tscn",
]

var _pending: Array[String] = []
var _rows: Array = []


func _initialize() -> void:
	_pending = ENEMY_SCENES.duplicate()
	for scene_path in _pending:
		_rows.append(_export_one(scene_path))
	_write_out()


func _export_one(scene_path: String) -> Dictionary:
	var ps := load(scene_path) as PackedScene
	if ps == null:
		return {"scene": scene_path, "error": "missing scene"}
	var enemy := ps.instantiate() as Enemy
	root.add_child(enemy)
	var stats := enemy.stats as EnemyStats
	var intents := stats.build_editor_preview_intents(enemy, enemy.editor_preview_action)
	intents = Intent.merge_by_kind_for_display(intents)
	var intent_rows: Array = []
	for intent in intents:
		if intent == null:
			continue
		var icon := intent.get_display_icon()
		var icon_path := icon.resource_path if icon != null else ""
		var label := ""
		if intent.kind == Intent.Kind.ATTACK:
			if not intent.current_text.is_empty():
				label = intent.current_text
			elif intent.display_number != Intent.NUMBER_HIDDEN:
				label = str(intent.display_number)
		intent_rows.append({"icon": icon_path, "label": label, "kind": int(intent.kind)})
	var health_text := "%d/%d" % [stats.max_health, stats.max_health]
	var bar_w := 0
	var sb := enemy.get_node_or_null("StatusBar") as StatusBar
	if sb != null:
		bar_w = sb.get_target_width()
	var health_row := enemy.stats_ui.get_node_or_null("HealthRow") as HealthBar
	if health_row != null and bar_w <= 0:
		bar_w = health_row.read_bar_host_width()
	enemy.queue_free()
	return {
		"scene": scene_path,
		"max_health": stats.max_health,
		"health_text": health_text,
		"bar_width": bar_w,
		"intents": intent_rows,
	}


func _write_out() -> void:
	var file := FileAccess.open("res://tools/enemy_editor_ui_preview.json", FileAccess.WRITE)
	if file == null:
		push_error("Cannot write preview json")
		quit(1)
		return
	file.store_string(JSON.stringify(_rows, "\t"))
	file.close()
	print("Wrote res://tools/enemy_editor_ui_preview.json (", _rows.size(), " enemies)")
	quit()
