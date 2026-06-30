class_name SaveGameMigrations
extends RefCounted

const _MIMIC_BATTLE_SCENE := preload("res://battles/mimic.tscn")
const _SHADOW_SAMURAI_BATTLE_SCENE := preload("res://battles/shadow_samurai.tscn")
const _EVIL_SPIRIT_BATTLE_SCENE := preload("res://battles/evil_spirit.tscn")
const _HEAVEN_GUARDIAN_BATTLE_SCENE := preload("res://battles/heaven_guardian.tscn")

## 旧战斗场景路径 → 新路径（统一 id_数量 命名）
const BATTLE_SCENE_PATH_RENAMES: Dictionary = {
	"res://battles/bats2.tscn": "res://battles/bats_2.tscn",
	"res://battles/bats3.tscn": "res://battles/bats_3.tscn",
	"res://battles/little_skeltons_4.tscn": "res://battles/little_skelton_4.tscn",
	"res://battles/little_skeltons_3.tscn": "res://battles/little_skelton_3.tscn",
	"res://battles/crab_and_bat.tscn": "res://battles/bat_crab.tscn",
	"res://battles/bat_rat.tscn": "res://battles/bat_rat_crab.tscn",
	"res://battles/bone_shewer.tscn": "res://battles/bone_chewer.tscn",
	"res://battles/bone_shewer.tres": "res://battles/bone_chewer.tres",
	"res://battles/elements_2.tscn": "res://battles/elementals_2.tscn",
	"res://battles/elements_3.tscn": "res://battles/elementals_3.tscn",
	"res://battles/elements_2.tres": "res://battles/elementals_2.tres",
	"res://battles/elements_3.tres": "res://battles/elementals_3.tres",
	"res://battles/elements_2.gd": "res://battles/elementals_2.gd",
	"res://battles/elements_3.gd": "res://battles/elementals_3.gd",
}

## 旧遗物 id → 新 id（读档时统一替换）
const RELIC_ID_RENAMES: Dictionary = {
	"healing_potion": "lycoris",
	"shattered_flower": "lycoris",
	"armor": "turtle_shell",
	"coupons": "VIP_card",
	"mana_potion": "candle",
	"explosive_barrel": "lava_shard",
	"martial_manual": "martial_scroll",
	"jade_axe": "emerald_axe",
}

## 旧药水 id → 新 id（读档时统一替换）
const POTION_ID_RENAMES: Dictionary = {
	"flame_potion": "explode_potion",
}

const _DEPRECATED_RELIC_TRES := "res://relics/deprecated_relic.tres"
const _DEPRECATED_RELIC_SCRIPT := "res://relics/deprecated_relic.gd"
const _PATCHED_SAVE_TMP := "user://savegame_patched.tres"


static func resolve_relic_id(relic_id: String) -> String:
	var current := String(relic_id)
	for _pass in range(8):
		if not RELIC_ID_RENAMES.has(current):
			return current
		current = String(RELIC_ID_RENAMES[current])
	return current


static func resolve_potion_id(potion_id: String) -> String:
	var current := String(potion_id)
	if POTION_ID_RENAMES.has(current):
		return String(POTION_ID_RENAMES[current])
	return current


static func remap_resource_path(path: String) -> String:
	if path.is_empty():
		return path
	if BATTLE_SCENE_PATH_RENAMES.has(path):
		return String(BATTLE_SCENE_PATH_RENAMES[path])
	var remapped := path
	remapped = remapped.replace("res://enemies/bone_shewer/", "res://enemies/bone_chewer/")
	remapped = remapped.replace("bone_shewer_", "bone_chewer_")
	remapped = remapped.replace("BoneShewer", "BoneChewer")
	return remapped


static func load_save_game_resource(path: String) -> SaveGame:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return ResourceLoader.load(path) as SaveGame
	text = patch_save_file_text(text)
	var file := FileAccess.open(_PATCHED_SAVE_TMP, FileAccess.WRITE)
	if file == null:
		push_error("无法写入临时存档以修复资源路径")
		return ResourceLoader.load(path) as SaveGame
	file.store_string(text)
	file = null
	var data := ResourceLoader.load(_PATCHED_SAVE_TMP) as SaveGame
	if FileAccess.file_exists(_PATCHED_SAVE_TMP):
		DirAccess.remove_absolute(_PATCHED_SAVE_TMP)
	return data


static func patch_save_file_text(text: String) -> String:
	for old_id: String in RELIC_ID_RENAMES.keys():
		var new_id: String = String(RELIC_ID_RENAMES[old_id])
		text = text.replace("res://relics/%s.tres" % old_id, "res://relics/%s.tres" % new_id)
		text = text.replace("res://relics/%s.gd" % old_id, "res://relics/%s.gd" % new_id)
	for path: String in _collect_relic_resource_paths(text):
		if ResourceLoader.exists(path):
			continue
		if path.ends_with(".gd"):
			text = text.replace(path, _DEPRECATED_RELIC_SCRIPT)
		elif path.ends_with(".tres"):
			text = text.replace(path, _DEPRECATED_RELIC_TRES)
	for old_path: String in BATTLE_SCENE_PATH_RENAMES.keys():
		var new_path: String = String(BATTLE_SCENE_PATH_RENAMES[old_path])
		text = text.replace(old_path, new_path)
	text = text.replace("res://enemies/bone_shewer/", "res://enemies/bone_chewer/")
	text = text.replace("bone_shewer_", "bone_chewer_")
	text = text.replace("BoneShewer", "BoneChewer")
	text = text.replace("res://potions/flame_potion.tres", "res://potions/explode_potion.tres")
	text = text.replace("res://potions/flame_potion.gd", "res://potions/explode_potion.gd")
	text = text.replace("res://art/potions/flame_potion.png", "res://art/potions/explode_potion.png")
	text = text.replace("res://statuses/exposed.tres", "res://statuses/vulnerable.tres")
	text = text.replace("res://statuses/exposed.gd", "res://statuses/vulnerable.gd")
	text = text.replace("exposed_duration", "vulnerable_duration")
	text = text.replace('"id": "exposed"', '"id": "vulnerable"')
	text = text.replace('id = "exposed"', 'id = "vulnerable"')
	text = text.replace('"exposed"', '"vulnerable"')
	for old_id: String in POTION_ID_RENAMES.keys():
		text = text.replace('"%s"' % old_id, '"%s"' % String(POTION_ID_RENAMES[old_id]))
	return text


static func _collect_relic_resource_paths(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	var search_from := 0
	const PREFIX := "res://relics/"
	while true:
		var idx := text.find(PREFIX, search_from)
		if idx < 0:
			break
		var end := idx + PREFIX.length()
		while end < text.length():
			var ch: String = text.substr(end, 1)
			if ch == "\"" or ch == "'" or ch == " " or ch == "\t" or ch == "\n" or ch == "\r":
				break
			end += 1
		var path := text.substr(idx, end - idx)
		if (path.ends_with(".tres") or path.ends_with(".gd")) and not out.has(path):
			out.append(path)
		search_from = end
	return out


static func sanitize_saved_relics(data: SaveGame) -> void:
	if data == null:
		return
	var resolved_ids := PackedStringArray()
	for relic_id in data.get_effective_relic_ids():
		var resolved := resolve_relic_id(String(relic_id))
		if GameContent.load_relic_template(resolved) != null:
			resolved_ids.append(resolved)
		else:
			resolved_ids.append(String(relic_id))
	data.saved_relic_ids = resolved_ids
	data.saved_spent_relic_ids = SaveGame.resolve_spent_relic_ids(data.saved_spent_relic_ids)
	data.saved_spent_relic_ids_csv = SaveGame.spent_ids_to_csv(data.saved_spent_relic_ids)
	var sanitized: Array[Relic] = []
	for relic_id in resolved_ids:
		var relic := GameContent.load_relic_for_save(String(relic_id))
		if relic != null:
			sanitized.append(relic)
	data.relics = sanitized


static func migrate(data: SaveGame) -> void:
	if data == null:
		return
	_migrate_renamed_battle_scenes(data)
	_migrate_relic_ids(data)
	_migrate_potion_ids(data)
	_migrate_card_upgrades(data)
	_migrate_act1_tense_unlocked(data)
	_migrate_act3_tense_unlocked(data)


static func _migrate_card_upgrades(data: SaveGame) -> void:
	if data.current_deck == null:
		return
	for c: Card in data.current_deck.cards:
		if c != null:
			c.migrate_from_upgrade_tracks()


static func _migrate_act1_tense_unlocked(data: SaveGame) -> void:
	if data.act1_tense_unlocked:
		return
	if data.act_number != 1:
		return
	# 旧存档：已通过第 8 层（row 8 宝箱层）则视为已解锁 tense。
	if data.floors_climbed > 8:
		data.act1_tense_unlocked = true
		return
	if data.last_room != null and data.last_room.row > 8:
		data.act1_tense_unlocked = true


static func _migrate_act3_tense_unlocked(data: SaveGame) -> void:
	if data.act3_tense_unlocked:
		return
	if data.act_number != 3:
		return
	# 旧存档：已通过第 8 层（row 8 宝箱层）则视为已解锁 tense。
	if data.floors_climbed > 8:
		data.act3_tense_unlocked = true
		return
	if data.last_room != null and data.last_room.row > 8:
		data.act3_tense_unlocked = true


static func _migrate_relic_ids(data: SaveGame) -> void:
	for old_id: String in RELIC_ID_RENAMES.keys():
		var new_id: String = String(RELIC_ID_RENAMES[old_id])
		_replace_relic_id_in_array(data.pending_relic_ids, old_id, new_id)
		_replace_relic_id_in_array(data.battle_reward_relic_ids, old_id, new_id)
		_replace_relic_id_in_array(data.battle_reward_pending_pre_relic_ids, old_id, new_id)
		_replace_relic_id_in_array(data.battle_reward_entry_pre_relic_ids, old_id, new_id)
		_replace_relic_id_in_array(data.scene_entry_relic_ids, old_id, new_id)
		_replace_relic_id_in_array(data.saved_relic_ids, old_id, new_id)
		_replace_relic_id_in_array(data.saved_spent_relic_ids, old_id, new_id)
		_replace_relic_id_in_array(data.scene_entry_spent_relic_ids, old_id, new_id)
		if data.combat_snapshot:
			_replace_relic_id_in_array(data.combat_snapshot.relic_ids, old_id, new_id)
			_replace_relic_id_in_array(data.combat_snapshot.spent_relic_ids, old_id, new_id)
	for i in range(data.relics.size()):
		var relic: Relic = data.relics[i]
		if relic == null or relic.id.is_empty():
			continue
		var resolved_id := resolve_relic_id(relic.id)
		var template := GameContent.load_relic_template(resolved_id)
		if template != null:
			data.relics[i] = template
		else:
			var fallback := GameContent.load_relic_for_save(relic.id)
			if fallback != null:
				data.relics[i] = fallback


static func _replace_relic_id_in_array(arr: PackedStringArray, old_id: String, new_id: String) -> void:
	for i in range(arr.size()):
		if arr[i] == old_id:
			arr[i] = new_id


static func _migrate_potion_ids(data: SaveGame) -> void:
	for old_id: String in POTION_ID_RENAMES.keys():
		var new_id: String = String(POTION_ID_RENAMES[old_id])
		_replace_relic_id_in_array(data.saved_potion_ids, old_id, new_id)
		_replace_relic_id_in_array(data.pending_potion_ids, old_id, new_id)
		_replace_relic_id_in_array(data.battle_reward_entry_pre_potion_ids, old_id, new_id)
		_replace_relic_id_in_array(data.scene_entry_potion_ids, old_id, new_id)
		if data.combat_snapshot:
			_replace_relic_id_in_array(data.combat_snapshot.potion_ids, old_id, new_id)


static func _migrate_renamed_battle_scenes(data: SaveGame) -> void:
	var act := maxi(1, data.act_number)
	for floor_arr: Array in data.map_data:
		for room: Room in floor_arr:
			_fix_toxic_ghost_battle_scene(room, act)
	if data.last_room:
		_fix_toxic_ghost_battle_scene(data.last_room, act)
	if data.combat_snapshot and data.combat_snapshot.room:
		_fix_toxic_ghost_battle_scene(data.combat_snapshot.room, act)


static func _remap_legacy_battle_scene(enemies: PackedScene) -> PackedScene:
	if enemies == null:
		return null
	var path := enemies.resource_path
	if BATTLE_SCENE_PATH_RENAMES.has(path):
		var renamed := String(BATTLE_SCENE_PATH_RENAMES[path])
		if ResourceLoader.exists(renamed):
			var scene := load(renamed) as PackedScene
			return scene if scene else enemies
	if path.is_empty() or not path.contains("battles/tier_"):
		return enemies
	const PREFIX := "res://battles/tier_"
	var idx := path.find(PREFIX)
	if idx < 0:
		return enemies
	var tail := path.substr(idx + PREFIX.length())
	var sep := tail.find("_")
	if sep <= 0:
		return enemies
	var new_path := "res://battles/" + tail.substr(sep + 1)
	if not ResourceLoader.exists(new_path):
		return enemies
	var scene := load(new_path) as PackedScene
	return scene if scene else enemies


static func _fix_toxic_ghost_battle_scene(room: Room, act_number: int) -> void:
	if not room or not room.battle_stats:
		return
	var enemies := room.battle_stats.enemies
	var remapped := _remap_legacy_battle_scene(enemies)
	if remapped != enemies and remapped != null:
		room.battle_stats.enemies = remapped
		enemies = remapped
	var path := enemies.resource_path if enemies else ""
	var tier := room.battle_stats.battle_tier
	var act := maxi(1, act_number)
	var stale_elite := (
		path.contains("elite/elite_mimic")
		or path.contains("battles/tier_")
		or path.contains("tier_2_mimic")
		or path.contains("tier_2_shadow_samurai")
		or path.contains("/shadow_samurai/elite/")
		or path.contains("shadow_samurai_elite")
		or path.contains("shadow_samurai/boss/")
	)
	var stale_boss := (
		path.contains("battles/tier_")
		or path.contains("tier_2_toxic_ghost")
		or path.contains("/toxic_ghost/")
		or path.contains("tier_2_evil_spirit")
		or path.contains("tier_3_evil_spirit")
		or path.contains("tier_3_heaven_guardian")
		or path.contains("evil_spirit_boss")
		or path.contains("heaven_guardian_boss")
		or path.contains("/boss/")
		or path.contains("/heaven_guardian/boss/")
	)
	if tier == 2 and (stale_elite or enemies == null):
		if act == 3:
			room.battle_stats.enemies = _SHADOW_SAMURAI_BATTLE_SCENE
		else:
			room.battle_stats.enemies = _MIMIC_BATTLE_SCENE
		return
	if tier != 3:
		return
	if act == 3:
		var needs_heaven := enemies == null or stale_boss or path.contains("/evil_spirit/")
		if needs_heaven:
			room.battle_stats.enemies = _HEAVEN_GUARDIAN_BATTLE_SCENE
	else:
		var wrongly_heaven := path.contains("/heaven_guardian/")
		if wrongly_heaven or enemies == null or stale_boss:
			room.battle_stats.enemies = _EVIL_SPIRIT_BATTLE_SCENE
