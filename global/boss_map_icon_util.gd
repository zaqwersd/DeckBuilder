class_name BossMapIconUtil
extends RefCounted

const DEFAULT_BOSS_ICON_PATH := "res://art/tile_0105.png"
const BOSS_ICON_DIR := "res://art/"
const BOSS_ICON_SUFFIX := "_icon.png"

static var _cache: Dictionary = {}


static func get_boss_map_icon(battle_stats: BattleStats) -> Texture2D:
	var boss_key := _get_boss_key(battle_stats)
	if boss_key.is_empty():
		return _load_default_icon()
	if _cache.has(boss_key):
		return _cache[boss_key] as Texture2D
	var texture := _try_load_boss_icon(boss_key)
	_cache[boss_key] = texture
	return texture


static func get_boss_display_name(battle_stats: BattleStats) -> String:
	if battle_stats == null or battle_stats.enemies == null:
		return "首领"
	var layout := battle_stats.enemies.instantiate()
	var fallback := "首领"
	for child in layout.get_children():
		if child is Enemy and child.stats is EnemyStats:
			var name_text := (child.stats as EnemyStats).get_display_name()
			if not name_text.is_empty():
				layout.queue_free()
				return name_text
	layout.queue_free()
	return fallback


static func uses_custom_map_icon(battle_stats: BattleStats) -> bool:
	var boss_key := _get_boss_key(battle_stats)
	if boss_key.is_empty():
		return false
	return ResourceLoader.exists(BOSS_ICON_DIR + boss_key + BOSS_ICON_SUFFIX)


static func _get_boss_key(battle_stats: BattleStats) -> String:
	if battle_stats == null:
		return ""
	if not battle_stats.resource_path.is_empty():
		return battle_stats.resource_path.get_file().get_basename()
	if battle_stats.enemies != null and not battle_stats.enemies.resource_path.is_empty():
		return battle_stats.enemies.resource_path.get_file().get_basename()
	return ""


static func _try_load_boss_icon(boss_key: String) -> Texture2D:
	var icon_path := BOSS_ICON_DIR + boss_key + BOSS_ICON_SUFFIX
	if ResourceLoader.exists(icon_path):
		var loaded := load(icon_path) as Texture2D
		if loaded != null:
			return loaded
	return _load_default_icon()


static func _load_default_icon() -> Texture2D:
	const DEFAULT_KEY := &"__default_boss_icon__"
	if _cache.has(DEFAULT_KEY):
		return _cache[DEFAULT_KEY] as Texture2D
	var texture := load(DEFAULT_BOSS_ICON_PATH) as Texture2D
	_cache[DEFAULT_KEY] = texture
	return texture
