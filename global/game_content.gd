class_name GameContent
extends RefCounted

const CHAR_CARDS_ROOT := "res://characters"
const COMMON_CARDS_DIR := "res://common_cards"
const RELICS_DIR := "res://relics"

## 已从奖励/图鉴等玩法池移除，资源文件仍保留在 `res://relics/` 供读档与日后启用。
const DISABLED_RELIC_IDS: Array[String] = ["confusing_staff", "blinding_potion"]

static var _relic_template_cache: Dictionary = {}


static func clear_relic_template_cache() -> void:
	_relic_template_cache.clear()


static func invalidate_relic_template(relic_id: String) -> void:
	var resolved := SaveGameMigrations.resolve_relic_id(String(relic_id))
	if resolved.is_empty():
		return
	_relic_template_cache.erase(resolved)


static func is_relic_enabled_in_game(relic_id: String) -> bool:
	return relic_id not in DISABLED_RELIC_IDS


static func load_card_template(card_id: String) -> Card:
	var path := find_card_resource_path(card_id)
	if path.is_empty():
		return null
	var res := load(path) as Card
	if res == null:
		return null
	return res.duplicate(true) as Card


static func load_cards_by_ids(ids: PackedStringArray) -> Array[Card]:
	var out: Array[Card] = []
	for id: String in ids:
		var c := load_card_template(id)
		if c != null:
			out.append(c)
	return out


static func load_relic_template(relic_id: String) -> Relic:
	var id := String(relic_id)
	if _relic_template_cache.has(id):
		var cached := _relic_template_cache[id] as Relic
		cached.reset_spent_state_for_load()
		return cached.duplicate(true) as Relic
	for path: String in _list_tres_files(RELICS_DIR):
		var res := load(path) as Relic
		if res == null or res.id.is_empty() or res.id == "_deprecated":
			continue
		if res.id == id:
			_relic_template_cache[id] = res.duplicate(true) as Relic
			return (_relic_template_cache[id] as Relic).duplicate(true) as Relic
	return null


## 读档/回滚：已知 id 加载模板，否则返回「已弃用」占位遗物
static func load_relic_for_save(relic_id: String) -> Relic:
	var resolved_id := SaveGameMigrations.resolve_relic_id(relic_id)
	var relic := load_relic_template(resolved_id)
	if relic != null:
		relic.reset_spent_state_for_load()
		return relic
	return DeprecatedRelic.create_for_legacy_id(relic_id)


static func load_relics_from_ids(ids: PackedStringArray) -> Array[Relic]:
	var out: Array[Relic] = []
	for relic_id in ids:
		var relic := load_relic_for_save(String(relic_id))
		if relic != null:
			out.append(relic)
	return out


static func load_all_relic_templates() -> Array[Relic]:
	var by_id: Dictionary = {}
	for path: String in _list_tres_files(RELICS_DIR):
		var res := load(path) as Relic
		if res == null or res.id.is_empty() or res.id == "_deprecated":
			continue
		if not is_relic_enabled_in_game(res.id):
			continue
		if by_id.has(res.id):
			continue
		by_id[res.id] = res.duplicate(true) as Relic
	var out: Array[Relic] = []
	for k: Variant in by_id.keys():
		out.append(by_id[k] as Relic)
	out.sort_custom(func(a: Relic, b: Relic) -> bool:
		return String(a.relic_name) < String(b.relic_name)
	)
	return out


static func find_card_resource_path(card_id: String) -> String:
	var fname := "%s.tres" % card_id
	var r := _scan_dir_for_file(CHAR_CARDS_ROOT, fname)
	if r.is_empty():
		r = _scan_dir_for_file(COMMON_CARDS_DIR, fname)
	return r


static func _list_tres_files(dir_path: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				for sub: String in _list_tres_files(dir_path.path_join(entry)):
					out.append(sub)
		elif entry.ends_with(".tres"):
			out.append(dir_path.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	return out


static func _scan_dir_for_file(dir_path: String, filename: String) -> String:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				var sub := _scan_dir_for_file(dir_path.path_join(entry), filename)
				if not sub.is_empty():
					dir.list_dir_end()
					return sub
		elif entry == filename:
			var found := dir_path.path_join(entry)
			dir.list_dir_end()
			return found
		entry = dir.get_next()
	dir.list_dir_end()
	return ""
