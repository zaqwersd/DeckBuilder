extends Node

## 命令行导出卡牌图鉴长图（通过场景启动，确保 autoload 可用）。
## 需在项目根目录执行，且不能使用 --headless（Dummy 渲染器无法截图）。
## godot --display-driver windows --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 64x64 tools/export_card_compendium.tscn -- --category blade --output exports/out.png

const USAGE := (
	"Usage (from project root): godot --display-driver windows --rendering-driver opengl3 "
	+ "--rendering-method gl_compatibility --resolution 64x64 tools/export_card_compendium.tscn "
	+ "-- --category <blade|common> [--output <path.png>] [--log <path.md>]"
)


func _ready() -> void:
	var user_args := OS.get_cmdline_user_args()
	var parsed := _parse_args(user_args)
	if not parsed.has("category"):
		parsed = _parse_args(_extract_args_after_dash_dash(OS.get_cmdline_args()))
	if not parsed.has("category"):
		push_error(USAGE)
		get_tree().quit(1)
		return

	var cat_name: String = parsed.get("category", "")
	var cat := CardCompendiumExport.category_from_cli_name(cat_name)
	if cat < 0:
		push_error("Invalid --category: %s (use blade or common)" % cat_name)
		push_error(USAGE)
		get_tree().quit(1)
		return

	var output_path: String = parsed.get("output", "")
	if output_path.is_empty():
		output_path = CardCompendiumExport.default_output_path(cat as CardCompendiumExport.Category)
	var log_path: String = parsed.get("log", "")

	var runner := CardCompendiumExport.ExportRunner.new()
	add_child(runner)
	await runner.run_export(
		cat as CardCompendiumExport.Category,
		output_path,
		log_path,
	)


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
		if arg == "--category" and i + 1 < args.size():
			out["category"] = args[i + 1]
			i += 2
			continue
		if arg == "--output" and i + 1 < args.size():
			out["output"] = args[i + 1]
			i += 2
			continue
		if arg == "--log" and i + 1 < args.size():
			out["log"] = args[i + 1]
			i += 2
			continue
		if arg.begins_with("--category="):
			out["category"] = arg.substr("--category=".length())
			i += 1
			continue
		if arg.begins_with("--output="):
			out["output"] = arg.substr("--output=".length())
			i += 1
			continue
		if arg.begins_with("--log="):
			out["log"] = arg.substr("--log=".length())
			i += 1
			continue
		i += 1
	return out
