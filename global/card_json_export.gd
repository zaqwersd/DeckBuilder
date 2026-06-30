class_name CardJsonExport
extends RefCounted

const TARGET_DISPLAY := {
	Card.Target.SELF: "自身",
	Card.Target.SINGLE_ENEMY: "单体敌人",
	Card.Target.ALL_ENEMIES: "全体敌人",
	Card.Target.EVERYONE: "所有人",
}

const DEFAULT_OUTPUT_PATH := "res://exports/cards.json"


static func build_export_data(categories: Array = []) -> Dictionary:
	var cats: Array = categories
	if cats.is_empty():
		cats = [CardCompendiumExport.Category.BLADE, CardCompendiumExport.Category.COMMON]

	var out: Dictionary = {
		"exported_at": Time.get_datetime_string_from_system(),
		"game_version": ProjectSettings.get_setting("application/config/name", ""),
		"categories": {},
	}

	for cat: Variant in cats:
		var cat_enum := cat as CardCompendiumExport.Category
		var slug := _category_slug(cat_enum)
		out["categories"][slug] = {
			"display_name": CardCompendiumExport.category_display_name(cat_enum),
			"folder": CardCompendiumExport.category_folder(cat_enum),
			"cards": cards_array_for_category(cat_enum),
		}
	return out


static func cards_array_for_category(cat: CardCompendiumExport.Category) -> Array:
	var templates := CardCompendiumExport.cards_for_category(cat)
	var slug := _category_slug(cat)
	var path_by_id := _paths_by_id(CardCompendiumExport.category_folder(cat))
	var out: Array = []
	for template: Card in templates:
		out.append(card_to_dict(template, slug, String(path_by_id.get(template.id, ""))))
	return out


static func card_to_dict(template: Card, category_slug: String, resource_path: String) -> Dictionary:
	var base := template.duplicate(true) as Card
	var upgraded := base.duplicate(true) as Card
	if base.defines_upgrade():
		upgraded.apply_upgrade()

	var base_desc_bb := CardCompendiumExport.listing_description_bbcode(base)
	var up_desc_bb := CardCompendiumExport.listing_description_bbcode(upgraded)
	var base_desc := CardCompendiumExport.bbcode_to_plain_text(base_desc_bb)
	var up_desc := CardCompendiumExport.bbcode_to_plain_text(up_desc_bb)

	var icon_path := ""
	if base.icon != null:
		icon_path = base.icon.resource_path

	return {
		"id": base.id,
		"name": base.get_display_name(),
		"category": category_slug,
		"resource_path": resource_path,
		"type": int(base.type),
		"type_name": CardVisualsBase.TYPE_DISPLAY.get(base.type, ""),
		"rarity": int(base.rarity),
		"rarity_name": Card.RARITY_DISPLAY_NAMES.get(base.rarity, str(base.rarity)),
		"target": int(base.target),
		"target_name": TARGET_DISPLAY.get(base.target, ""),
		"cost": base.cost,
		"cost_text": _cost_text(base),
		"cost_upgraded": upgraded.cost if base.defines_upgrade() else base.cost,
		"cost_text_upgraded": _cost_text(upgraded) if base.defines_upgrade() else _cost_text(base),
		"is_x_cost": base.is_x_cost(),
		"is_unplayable": base.is_unplayable(),
		"exhausts": base.exhausts,
		"exhausts_upgraded": upgraded.exhausts if base.defines_upgrade() else base.exhausts,
		"retains": base.retains,
		"ethereal": base.ethereal,
		"intrinsic": base.intrinsic,
		"intrinsic_upgraded": upgraded.intrinsic if base.defines_upgrade() else base.intrinsic,
		"can_upgrade": base.defines_upgrade(),
		"description_bbcode": base_desc_bb,
		"description": base_desc,
		"description_bbcode_upgraded": up_desc_bb if up_desc_bb != base_desc_bb else base_desc_bb,
		"description_upgraded": up_desc if up_desc != base_desc else base_desc,
		"meta_line": CardCompendiumExport.card_meta_line(base),
		"meta_line_upgraded": (
			CardCompendiumExport.card_meta_line(upgraded)
			if base.defines_upgrade()
			else CardCompendiumExport.card_meta_line(base)
		),
		"icon_path": icon_path,
		"upgrade_tracks": _upgrade_tracks_dict(base, upgraded),
	}


static func _upgrade_tracks_dict(base: Card, upgraded: Card) -> Array:
	var out: Array = []
	for track_id: String in base.get_upgrade_track_ids():
		var chain := base.get_upgrade_chain(track_id)
		if chain.is_empty():
			continue
		var entry: Dictionary = {
			"id": track_id,
			"values": Array(chain),
			"base": chain[0],
		}
		if chain.size() > 1:
			entry["upgraded"] = chain[chain.size() - 1]
		out.append(entry)
	return out


static func _cost_text(card: Card) -> String:
	if card.is_x_cost():
		return "X"
	if card.is_unplayable():
		return "不可打出"
	return str(card.cost)


static func _category_slug(cat: CardCompendiumExport.Category) -> String:
	return "blade" if cat == CardCompendiumExport.Category.BLADE else "common"


static func _paths_by_id(folder: String) -> Dictionary:
	var out: Dictionary = {}
	for p: String in _list_card_tres_paths(folder):
		var res := load(p)
		if res == null or not (res is Card):
			continue
		var template := res as Card
		if not out.has(template.id):
			out[template.id] = p
	return out


static func _list_card_tres_paths(folder: String) -> Array[String]:
	var out: Array[String] = []
	var da := DirAccess.open(folder)
	if da == null:
		return out
	da.list_dir_begin()
	while true:
		var fn := da.get_next()
		if fn == "":
			break
		if fn == "." or fn == "..":
			continue
		if da.current_is_dir():
			continue
		if not fn.ends_with(".tres"):
			continue
		if fn.ends_with(".tres.remap"):
			continue
		out.append(folder.path_join(fn))
	da.list_dir_end()
	out.sort()
	return out


static func write_json(output_path: String, data: Dictionary) -> Error:
	var err := CardCompendiumExport.ensure_parent_dir_for(output_path)
	if err != OK:
		return err
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return OK
