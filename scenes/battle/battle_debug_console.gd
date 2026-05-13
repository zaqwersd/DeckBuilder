class_name BattleDebugConsole
extends Control

## 全局调试：反引号 ` 打开；Esc /「关闭」收起。战斗中可用 \\enemy \\card \\health；任意时刻 \\event。
## 挂在 Run 的 CanvasLayer 上（全地图/商店/战斗均可输入）。

const BATTLES_DIR := "res://battles"
const CHAR_ROOT := "res://characters"
const COMMON_CARDS_DIR := "res://common_cards"
const EVENT_ROOMS_DIR := "res://scenes/event_rooms"
const RELICS_DIR := "res://relics"
const POOL_TRES := "battle_stats_pool.tres"
const SUGGEST_MAX := 40
const SUGGEST_ROW_PX := 22.0
## 底边贴视口底，高度从此向上长；避免内容测量过小时整条面板只有几条像素高。
const PANEL_MIN_HEIGHT := 220.0
const PANEL_CONTENT_PAD := 36.0

var _run: Run
var _panel: Panel
var _scroll: ScrollContainer
var _line: LineEdit
var _hint: Label
var _suggest: ItemList

var _battle_ids: PackedStringArray = PackedStringArray()
var _card_ids: PackedStringArray = PackedStringArray()
var _event_ids: PackedStringArray = PackedStringArray()
var _relic_ids: PackedStringArray = PackedStringArray()


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 90
	set_process_input(true)
	_ensure_run()
	_rebuild_id_caches()
	_build_ui()
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)


func _ensure_run() -> void:
	if _run != null and is_instance_valid(_run):
		return
	_run = get_tree().get_first_node_in_group("run") as Run


func _current_battle() -> Node:
	_ensure_run()
	if _run == null or not is_instance_valid(_run):
		return null
	var cv: Node = _run.current_view
	if cv == null or cv.get_child_count() == 0:
		return null
	var n: Node = cv.get_child(0)
	if n.has_method("debug_replace_battle"):
		return n
	return null


func _on_viewport_size_changed() -> void:
	_ensure_overlay_rect()
	_apply_panel_to_viewport()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and visible:
			_toggle_visible()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_QUOTELEFT:
			if not visible:
				_toggle_visible()
				get_viewport().set_input_as_handled()


func _toggle_visible() -> void:
	visible = not visible
	if visible and _line:
		_line.grab_focus()
		_ensure_overlay_rect()
		call_deferred("_apply_panel_to_viewport")
	elif _line:
		_line.release_focus()
		_hide_suggestions()


func _on_close_pressed() -> void:
	if not visible:
		return
	visible = false
	if _line:
		_line.release_focus()
	_hide_suggestions()


func _build_ui() -> void:
	_ensure_overlay_rect()

	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.clip_contents = true
	add_child(_panel)

	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_panel.add_child(_scroll)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_scroll.add_child(vb)

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 8)
	vb.add_child(top_bar)

	var title := Label.new()
	title.text = "调试控制台"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.custom_minimum_size = Vector2(72, 32)
	close_btn.pressed.connect(_on_close_pressed)
	top_bar.add_child(close_btn)

	_hint = Label.new()
	_hint.text = "隐藏时按 ` 打开 | Esc /「关闭」| \\enemy \\card \\health（须战斗中）| \\event | \\relic add/delete id"
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(_hint)

	_line = LineEdit.new()
	_line.placeholder_text = "输入指令…"
	_line.clear_button_enabled = true
	_line.text_submitted.connect(_on_line_submitted)
	_line.text_changed.connect(_on_line_text_changed)
	_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(_line)

	_suggest = ItemList.new()
	_suggest.visible = false
	_suggest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_suggest.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_suggest.allow_reselect = true
	_suggest.focus_mode = Control.FOCUS_CLICK
	_suggest.item_selected.connect(_on_suggest_item_selected)
	vb.add_child(_suggest)


## 视口铺满：不要用 FULL_RECT 再手写 position/size，在 stretch viewport 下容易把高度算成 0。
func _ensure_overlay_rect() -> void:
	if not is_inside_tree():
		return
	var r := get_viewport().get_visible_rect()
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	anchor_right = 0.0
	anchor_bottom = 0.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	position = r.position
	size = r.size


func _apply_panel_to_viewport() -> void:
	if _panel == null or _scroll == null or not is_inside_tree():
		return
	_ensure_overlay_rect()
	var r := get_viewport().get_visible_rect()
	var margin_side := 10.0
	var inner_pad := 8.0
	var margin_top_reserve := 8.0
	await get_tree().process_frame
	_ensure_overlay_rect()
	var w: float = maxf(32.0, r.size.x - 2.0 * margin_side)
	var inner_w: float = maxf(1.0, w - 2.0 * inner_pad)
	# 先给 Scroll 横向宽度，Hint 换行后纵向最小高度才可靠
	_scroll.size = Vector2(inner_w, maxf(400.0, r.size.y * 0.5))
	await get_tree().process_frame
	var ch: float = _scroll.get_combined_minimum_size().y
	var max_h: float = maxf(PANEL_MIN_HEIGHT + 1.0, r.size.y - margin_top_reserve)
	var content_h: float = ch + PANEL_CONTENT_PAD
	var h: float = clampf(content_h, PANEL_MIN_HEIGHT, max_h)
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.size = Vector2(w, h)
	var bottom_y: float = r.position.y + r.size.y
	_panel.global_position = Vector2(r.position.x + margin_side, bottom_y - h)
	var inner_h: float = maxf(1.0, h - 2.0 * inner_pad)
	_scroll.position = Vector2(inner_pad, inner_pad)
	_scroll.size = Vector2(inner_w, inner_h)


func _rebuild_id_caches() -> void:
	_battle_ids = _collect_battle_basenames()
	_card_ids = _collect_all_card_basenames()
	_event_ids = _collect_event_room_basenames()
	_relic_ids = _collect_relic_ids()


func _collect_battle_basenames() -> PackedStringArray:
	var out: Array[String] = []
	var dir := DirAccess.open(BATTLES_DIR)
	if dir == null:
		return PackedStringArray()
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".tres") and entry != POOL_TRES:
			out.append(entry.get_basename())
		entry = dir.get_next()
	dir.list_dir_end()
	out.sort()
	var packed := PackedStringArray()
	for s in out:
		packed.append(s)
	return packed


func _collect_event_room_basenames() -> PackedStringArray:
	var out: Array[String] = []
	var dir := DirAccess.open(EVENT_ROOMS_DIR)
	if dir == null:
		return PackedStringArray()
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".tscn"):
			out.append(entry.get_basename())
		entry = dir.get_next()
	dir.list_dir_end()
	out.sort()
	var packed := PackedStringArray()
	for s in out:
		packed.append(s)
	return packed


func _collect_relic_ids() -> PackedStringArray:
	var out: Array[String] = []
	var dir := DirAccess.open(RELICS_DIR)
	if dir == null:
		return PackedStringArray()
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".tres"):
			var path := RELICS_DIR.path_join(entry)
			var r := ResourceLoader.load(path)
			if r is Relic and (r as Relic).id.strip_edges() != "":
				out.append((r as Relic).id)
		entry = dir.get_next()
	dir.list_dir_end()
	out.sort()
	var packed := PackedStringArray()
	for s in out:
		packed.append(s)
	return packed


func _collect_all_card_basenames() -> PackedStringArray:
	var acc: Dictionary = {}
	_accum_card_basenames(CHAR_ROOT, acc)
	_accum_card_basenames(COMMON_CARDS_DIR, acc)
	var arr: Array[String] = []
	for k in acc:
		arr.append(String(k))
	arr.sort()
	var packed := PackedStringArray()
	for s in arr:
		packed.append(s)
	return packed


func _accum_card_basenames(dir_path: String, acc: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_accum_card_basenames(dir_path.path_join(entry), acc)
		elif entry.ends_with(".tres"):
			var in_char_cards := dir_path.contains("/cards") or dir_path.contains("\\cards")
			var in_common := dir_path == COMMON_CARDS_DIR
			if in_char_cards or in_common:
				acc[entry.get_basename()] = true
		entry = dir.get_next()
	dir.list_dir_end()


func _on_line_text_changed(_new_text: String) -> void:
	_refresh_suggestions()


func _refresh_suggestions() -> void:
	if _suggest == null or _line == null:
		return
	_suggest.clear()
	var ctx := _parse_autocomplete_context(_line.text)
	if ctx.is_empty():
		_hide_suggestions()
		return
	var kind: String = ctx["kind"]
	var prefix: String = ctx["prefix"]
	var pool: PackedStringArray
	match kind:
		"enemy":
			pool = _battle_ids
		"card":
			pool = _card_ids
		"event":
			pool = _event_ids
		"relic":
			pool = _relic_ids
		_:
			_hide_suggestions()
			return
	var matches: Array[String] = _filter_ids(pool, prefix)
	if matches.is_empty():
		_hide_suggestions()
		return
	var n := mini(matches.size(), SUGGEST_MAX)
	for i in n:
		_suggest.add_item(matches[i])
	var rows := mini(n, 10)
	_suggest.custom_minimum_size.y = rows * SUGGEST_ROW_PX + 8.0
	_suggest.visible = true
	call_deferred("_apply_panel_to_viewport")


func _hide_suggestions() -> void:
	if _suggest:
		_suggest.clear()
		_suggest.visible = false
		_suggest.custom_minimum_size.y = 0.0
	call_deferred("_apply_panel_to_viewport")


func _parse_autocomplete_context(line: String) -> Dictionary:
	var t := line.strip_edges()
	if t.begins_with("\\enemy"):
		var rest := t.substr(6)
		if rest.begins_with(" "):
			rest = rest.substr(1)
		return {"kind": "enemy", "prefix": rest}
	if t.begins_with("\\card"):
		var rest2 := t.substr(5)
		if rest2.begins_with(" "):
			rest2 = rest2.substr(1)
		return {"kind": "card", "prefix": rest2}
	if t.begins_with("\\event"):
		var rest3 := t.substr(6)
		if rest3.begins_with(" "):
			rest3 = rest3.substr(1)
		return {"kind": "event", "prefix": rest3}
	if t.begins_with("\\relic"):
		var rest4 := t.substr(6)
		if rest4.begins_with(" "):
			rest4 = rest4.substr(1)
		var parts := rest4.split(" ", false, 1)
		var sub := parts[0].strip_edges().to_lower() if parts.size() > 0 else ""
		var pref := ""
		if parts.size() > 1:
			pref = parts[1].strip_edges()
		return {"kind": "relic", "sub": sub, "prefix": pref}
	return {}


func _filter_ids(pool: PackedStringArray, prefix: String) -> Array[String]:
	var p := prefix.strip_edges()
	var p_lower := p.to_lower()
	var seen: Dictionary = {}
	var out: Array[String] = []
	for i in pool.size():
		var id: String = pool[i]
		var hit := false
		if p.is_empty():
			hit = true
		elif id.begins_with(p) or id.to_lower().begins_with(p_lower):
			hit = true
		elif id.to_lower().contains(p_lower):
			hit = true
		if hit and not seen.has(id):
			seen[id] = true
			out.append(id)
	out.sort()
	return out


func _on_suggest_item_selected(index: int) -> void:
	if _suggest == null or _line == null:
		return
	if index < 0 or index >= _suggest.item_count:
		return
	var picked: String = _suggest.get_item_text(index)
	var ctx := _parse_autocomplete_context(_line.text)
	if ctx.is_empty():
		return
	var kind: String = ctx["kind"]
	if kind == "enemy":
		_line.text = "\\enemy %s" % picked
	elif kind == "card":
		_line.text = "\\card %s" % picked
	elif kind == "event":
		_line.text = "\\event %s" % picked
	elif kind == "relic":
		var sub: String = str(ctx.get("sub", ""))
		if sub == "delete":
			_line.text = "\\relic delete %s" % picked
		else:
			_line.text = "\\relic add %s" % picked
	_line.caret_column = _line.text.length()
	_hide_suggestions()
	_line.grab_focus()


func _on_line_submitted(text: String) -> void:
	var msg := _run_command(text.strip_edges())
	_hint.text = msg
	_line.clear()
	_hide_suggestions()


func _run_command(text: String) -> String:
	if text.is_empty():
		return _hint.text
	var parts := text.split(" ", false, 1)
	var cmd := parts[0]
	var arg := parts[1].strip_edges() if parts.size() > 1 else ""
	match cmd:
		"\\enemy":
			return _cmd_enemy(arg)
		"\\card":
			return _cmd_card(arg)
		"\\health":
			return _cmd_health(arg)
		"\\event":
			return _cmd_event(arg)
		"\\relic":
			return _cmd_relic(arg)
		_:
			return "未知指令。使用 \\enemy / \\card / \\health（战斗）| \\event | \\relic add/delete id"


func _cmd_event(arg: String) -> String:
	if arg.is_empty():
		return "\\event 需要 id，例如 helpful_boi_event 或 res://scenes/event_rooms/gamble_event.tscn"
	_ensure_run()
	if _run == null or not _run.has_method("debug_enter_event"):
		return "未找到 Run 或 debug_enter_event。"
	return _run.debug_enter_event(arg)


func _cmd_enemy(arg: String) -> String:
	if arg.is_empty():
		return "\\enemy 需要参数，例如 tier_0_crab 或 res://battles/tier_1_bat_crab.tres"
	var bt := _current_battle()
	if bt == null:
		return "当前不在战斗，无法切换敌人布局。"
	var path := arg
	if path.begins_with("res://"):
		pass
	elif not path.ends_with(".tres"):
		path = "%s/%s.tres" % [BATTLES_DIR, path.trim_suffix(".tres")]
	if not ResourceLoader.exists(path):
		return "找不到战斗资源：%s" % path
	var stats: BattleStats = ResourceLoader.load(path) as BattleStats
	if stats == null:
		return "不是有效的 BattleStats：%s" % path
	bt.call("debug_replace_battle", stats)
	return "已切换战斗：%s" % path


func _cmd_card(arg: String) -> String:
	if arg.is_empty():
		return "\\card 需要卡牌 id，例如 blade_slash"
	var bt := _current_battle()
	if bt == null:
		return "当前不在战斗，无法加入手牌。"
	var path := _find_card_tres_path(arg)
	if path.is_empty():
		return "找不到 id 为「%s」的卡牌 .tres" % arg
	var card_res: Resource = ResourceLoader.load(path)
	if card_res == null or not (card_res is Card):
		return "加载失败或不是 Card：%s" % path
	var inst: Card = (card_res as Card).duplicate(true) as Card
	var bu: BattleUI = bt.get("battle_ui") as BattleUI
	if bu == null:
		return "BattleUI 未就绪。"
	var hand: Hand = bu.hand
	if hand == null:
		return "Hand 未就绪。"
	hand.add_card(inst)
	return "已加入手牌：%s（%s）" % [inst.get_display_name(), path]


func _find_relic_tres_path(relic_id: String) -> String:
	var rid := relic_id.strip_edges()
	if rid.is_empty():
		return ""
	var direct := RELICS_DIR.path_join("%s.tres" % rid)
	if ResourceLoader.exists(direct):
		var r0 := ResourceLoader.load(direct)
		if r0 is Relic and (r0 as Relic).id == rid:
			return direct
	var dir := DirAccess.open(RELICS_DIR)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".tres"):
			var path := RELICS_DIR.path_join(entry)
			var r := ResourceLoader.load(path)
			if r is Relic and (r as Relic).id == rid:
				dir.list_dir_end()
				return path
		entry = dir.get_next()
	dir.list_dir_end()
	return ""


func _cmd_relic(arg: String) -> String:
	var bits := arg.split(" ", false, 1)
	if bits.is_empty():
		return "用法：\\relic add id | \\relic delete id"
	var verb := bits[0].strip_edges().to_lower()
	var rest := bits[1].strip_edges() if bits.size() > 1 else ""
	if verb != "add" and verb != "delete":
		return "用法：\\relic add id | \\relic delete id（动词：add / delete）"
	if rest.is_empty():
		return "\\relic %s 需要遗物 id，例如 defect_machine" % verb
	_ensure_run()
	if _run == null or not is_instance_valid(_run):
		return "未找到 Run。"
	var rh: RelicHandler = _run.relic_handler
	if rh == null:
		return "未找到 RelicHandler。"
	if verb == "delete":
		if not rh.remove_relic_by_id(rest):
			return "未持有遗物：%s" % rest
		return "已移除遗物：%s" % rest
	var path := _find_relic_tres_path(rest)
	if path.is_empty():
		return "找不到遗物 id：%s" % rest
	var res := ResourceLoader.load(path)
	if res == null or not (res is Relic):
		return "加载失败或不是 Relic：%s" % path
	var inst: Relic = (res as Relic).duplicate(true) as Relic
	if rh.has_relic(inst.id):
		return "已拥有遗物：%s" % inst.id
	rh.add_relic(inst, false)
	return "已添加遗物：%s（%s）" % [inst.relic_name, inst.id]


func _cmd_health(arg: String) -> String:
	if arg.is_empty():
		return "\\health 需要整数，例如 30"
	var bt := _current_battle()
	if bt == null:
		return "当前不在战斗，无法改生命。"
	var cs: CharacterStats = bt.get("char_stats") as CharacterStats
	if cs == null:
		return "无 CharacterStats。"
	if not arg.is_valid_int():
		return "生命值必须是整数：%s" % arg
	var v := int(arg)
	cs.health = clampi(v, 0, cs.max_health)
	return "生命值已设为 %d / %d" % [cs.health, cs.max_health]


func _find_card_tres_path(card_id: String) -> String:
	var fname := "%s.tres" % card_id
	var r := _scan_dir_for_file(CHAR_ROOT, fname)
	if r.is_empty():
		r = _scan_dir_for_file(COMMON_CARDS_DIR, fname)
	return r


func _scan_dir_for_file(dir_path: String, filename: String) -> String:
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
			var out := dir_path.path_join(entry)
			dir.list_dir_end()
			return out
		entry = dir.get_next()
	dir.list_dir_end()
	return ""
