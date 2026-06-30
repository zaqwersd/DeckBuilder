extends Node

## 命令行导出全部卡牌数据为 JSON（无需渲染，可 headless）。
## godot --headless --path . tools/export_cards_json.tscn -- --output exports/cards.json

const ExportLib := preload("res://global/card_json_export.gd")
const USAGE := "Usage: godot --headless tools/export_cards_json.tscn -- [--output <path.json>] [--category all|blade|common]"


func _ready() -> void:
	var user_args := OS.get_cmdline_user_args()
	var parsed := _parse_args(user_args)
	if parsed.is_empty():
		parsed = _parse_args(_extract_args_after_dash_dash(OS.get_cmdline_args()))

	var output_path: String = parsed.get("output", ExportLib.DEFAULT_OUTPUT_PATH)
	var category_name: String = parsed.get("category", "all").strip_edges().to_lower()

	var categories: Array = []
	match category_name:
		"all", "":
			categories = [CardCompendiumExport.Category.BLADE, CardCompendiumExport.Category.COMMON]
		"blade", "剑客":
			categories = [CardCompendiumExport.Category.BLADE]
		"common", "公共":
			categories = [CardCompendiumExport.Category.COMMON]
		_:
			push_error("Invalid --category: %s" % category_name)
			push_error(USAGE)
			get_tree().quit(1)
			return

	var data: Dictionary = ExportLib.build_export_data(categories)
	var err: Error = ExportLib.write_json(output_path, data)
	if err != OK:
		push_error("Failed to write JSON: %s (%s)" % [output_path, error_string(err)])
		get_tree().quit(1)
		return

	var card_count := 0
	for slug: Variant in data["categories"].keys():
		card_count += (data["categories"][slug]["cards"] as Array).size()
	print("Exported %d cards to %s" % [card_count, ProjectSettings.globalize_path(output_path)])
	get_tree().quit(0)


func _extract_args_after_dash_dash(args: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = []
	var found := false
	for arg: String in args:
		if found:
			out.append(arg)
		elif arg == "--":
			found = true
	return out


func _parse_args(args: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	var i := 0
	while i < args.size():
		var arg := args[i]
		if arg == "--output" and i + 1 < args.size():
			out["output"] = args[i + 1]
			i += 2
			continue
		if arg == "--category" and i + 1 < args.size():
			out["category"] = args[i + 1]
			i += 2
			continue
		if arg.begins_with("--output="):
			out["output"] = arg.substr("--output=".length())
			i += 1
			continue
		if arg.begins_with("--category="):
			out["category"] = arg.substr("--category=".length())
			i += 1
			continue
		i += 1
	return out
