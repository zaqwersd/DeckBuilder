class_name SpookEnemyStats
extends EnemyStats

const SPOOK_STATS_PATH := "res://enemies/ghost_summoner/spook.tres"
const SPOOK_SLOT := 2
const INITIAL_HEALTH := 100
const RESPAWN_HEALTH := 80

const VARIANT_ART: Dictionary = {
	"red": preload("res://art/spook_red.png"),
	"blue": preload("res://art/spook_blue.png"),
	"green": preload("res://art/spook_green.png"),
}

const VARIANT_AI: Dictionary = {
	"red": preload("res://enemies/ghost_summoner/spook_red_ai.tscn"),
	"blue": preload("res://enemies/ghost_summoner/spook_blue_ai.tscn"),
	"green": preload("res://enemies/ghost_summoner/spook_green_ai.tscn"),
}

const VARIANT_DISPLAY_SUFFIX: Dictionary = {
	"red": "（红）",
	"green": "（绿）",
	"blue": "（蓝）",
}

## 运行时由 `create_for_variant` 写入；红/蓝/绿共用 `spook.tres` 的 UI 偏移。
## 须 @export：`Enemy.set_enemy_stats` 会 duplicate stats，非导出字段会在复制时丢失。
@export var spook_variant: String = "red"


func get_display_name() -> String:
	var base := super.get_display_name()
	if base.is_empty():
		base = "小幽灵"
	return base + String(VARIANT_DISPLAY_SUFFIX.get(_effective_variant(), ""))


func create_instance() -> Resource:
	var instance := super.create_instance() as SpookEnemyStats
	instance.spook_variant = spook_variant
	return instance


func _effective_variant() -> String:
	if VARIANT_ART.get(spook_variant) == art:
		return spook_variant
	for key: String in VARIANT_ART:
		if VARIANT_ART[key] == art:
			return key
	return spook_variant


static func apply_spawn_health(stats: EnemyStats, hp: int) -> void:
	if stats == null:
		return
	if stats is Stats:
		(stats as Stats).initialize_health(hp)


static func create_for_variant(variant: String) -> SpookEnemyStats:
	var template := load(SPOOK_STATS_PATH) as SpookEnemyStats
	var instance := template.create_instance() as SpookEnemyStats
	instance.apply_variant(variant)
	return instance


static func stats_for_variant(variant: String) -> SpookEnemyStats:
	return create_for_variant(variant)


static func variant_for_stats(stats: EnemyStats) -> String:
	if stats is SpookEnemyStats:
		return (stats as SpookEnemyStats).spook_variant
	return ""


func apply_variant(variant: String) -> void:
	spook_variant = variant
	if VARIANT_ART.has(variant):
		art = VARIANT_ART[variant]
	if VARIANT_AI.has(variant):
		ai = VARIANT_AI[variant]


func setup_battle_visual(enemy: Node) -> void:
	SpookEnemyVisual.attach_to(enemy)
