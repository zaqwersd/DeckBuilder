class_name BattleDebugConsole
extends Control

## 全局调试：反引号 ` 打开；Esc /「关闭」收起。输入 \\help 查看可用指令。
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
	_hint.text = "按 ` 打开控制台 | Esc 关闭 | \\help 查看指令"
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(_hint)

	_line = LineEdit.new()
	_line.placeholder_text = "例：\\card hand blade_slash 2 | \\card deck ghost | \\card blade_slash"
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
	# 添加特殊快速选项
	out.append("campfire")
	out.append("shop")
	
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
	var prefix: String = str(ctx.get("prefix", ""))
	var pool: PackedStringArray
	match kind:
		"enemy":
			pool = _battle_ids
		"card":
			_fill_card_command_suggestions()
			return
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
		var rest2 := t.substr(5).strip_edges()
		return {"kind": "card", "rest": rest2}
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


## PackedStringArray 多元素字面量在部分 Godot 版本下不能作为 const，用成员变量初始化。
var _CARD_POS_SUGGEST: PackedStringArray = PackedStringArray([
	"hand", "deck", "draw", "discard", "exhaust",
])


func _card_cmd_split_args(arg: String) -> Array[String]:
	var out: Array[String] = []
	for part in arg.split(" ", false):
		var x := part.strip_edges()
		if not x.is_empty():
			out.append(x)
	return out


func _card_cmd_canonical_position(tok: String) -> String:
	var sl := tok.strip_edges().to_lower()
	match sl:
		"hand":
			return "hand"
		"deck":
			return "deck"
		"draw":
			return "draw"
		"discard":
			return "discard"
		"exhaust":
			return "exhaust"
		_:
			return ""


func _card_cmd_where_label(where: String) -> String:
	match where:
		"hand":
			return "hand"
		"deck":
			return "deck"
		"draw":
			return "draw pile"
		"discard":
			return "discard pile"
		"exhaust":
			return "exhaust pile"
	return where


func _fill_card_command_suggestions() -> void:
	var ctx := _parse_autocomplete_context(_line.text)
	var rest: String = str(ctx.get("rest", ""))
	var bits := _card_cmd_split_args(rest)
	var matches: Array[String] = []
	if bits.is_empty():
		matches.append_array(_filter_ids(_CARD_POS_SUGGEST, ""))
	elif bits.size() == 1:
		var b0 := bits[0]
		var c0 := _card_cmd_canonical_position(b0)
		if c0 != "":
			var all_ids := _filter_ids(_card_ids, "")
			var lim := mini(SUGGEST_MAX, all_ids.size())
			for j in range(lim):
				matches.append(all_ids[j])
		else:
			matches.append_array(_filter_ids(_CARD_POS_SUGGEST, b0))
			for id in _filter_ids(_card_ids, b0):
				if matches.size() >= SUGGEST_MAX:
					break
				if not matches.has(id):
					matches.append(id)
	else:
		var cfirst := _card_cmd_canonical_position(bits[0])
		if cfirst != "":
			var card_pref := bits[1] if bits.size() >= 2 else ""
			matches.append_array(_filter_ids(_card_ids, card_pref))
		elif bits.size() >= 2 and bits[1].is_valid_int():
			matches.append_array(_filter_ids(_card_ids, bits[0]))
		else:
			matches.append_array(_filter_ids(_card_ids, bits[0]))
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
		var tline := _line.text.strip_edges()
		var arg_part := tline.substr(5).strip_edges() if tline.begins_with("\\card") else ""
		var bits := _card_cmd_split_args(arg_part)
		var picked_pos := _card_cmd_canonical_position(picked)
		if bits.is_empty():
			if picked_pos != "":
				_line.text = "\\card %s " % picked
			else:
				_line.text = "\\card %s" % picked
		elif bits.size() == 1:
			var c0 := _card_cmd_canonical_position(bits[0])
			if c0 != "":
				_line.text = "\\card %s %s" % [bits[0], picked]
			elif picked_pos != "":
				_line.text = "\\card %s " % picked
			else:
				_line.text = "\\card %s" % picked
		elif _card_cmd_canonical_position(bits[0]) != "":
			if bits.size() >= 3:
				_line.text = "\\card %s %s %s" % [bits[0], picked, bits[2]]
			else:
				_line.text = "\\card %s %s" % [bits[0], picked]
		else:
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
	_run_command_async(text.strip_edges())


## 异步执行命令
func _run_command_async(text: String) -> void:
	var msg = await _run_command_with_async(text)
	_hint.text = msg
	_line.clear()
	_hide_suggestions()


## 支持异步命令的版本
func _run_command_with_async(text: String) -> String:
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
			return await _cmd_relic_async(arg)
		"\\win":
			return _cmd_win(arg)
		"\\help":
			return _cmd_help()
		"\\jump":
			return _cmd_jump(arg)
		_:
			return "未知指令。输入 \\help 查看可用指令"


## 保留同步版本供其他代码调用
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
			return "请使用命令行输入 relic 命令"
		"\\win":
			return _cmd_win(arg)
		"\\help":
			return _cmd_help()
		"\\jump":
			return _cmd_jump(arg)
		_:
			return "未知指令。输入 \\help 查看可用指令"


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
	var bits := _card_cmd_split_args(arg)
	if bits.is_empty():
		return "用法：\\card <位置> <id> [数量]；战斗外仅 deck。位置：hand | deck | draw | discard | exhaust。省略位置时视为 hand（须战斗中）。例：\\card hand blade_slash 2"
	_ensure_run()
	if _run == null or not is_instance_valid(_run):
		return "未找到 Run。"
	var cs: CharacterStats = _run.character
	if cs == null:
		return "无 CharacterStats。"
	var bt := _current_battle()
	var in_battle := bt != null

	var where: String
	var card_id: String
	var count: int = 1

	if bits.size() == 1:
		where = "hand"
		card_id = bits[0]
	elif bits.size() == 2:
		var p2 := _card_cmd_canonical_position(bits[0])
		if p2 != "":
			where = p2
			card_id = bits[1]
		elif bits[1].is_valid_int():
			where = "hand"
			card_id = bits[0]
			count = clampi(int(bits[1]), 1, 99)
		else:
			return "无法理解：%s（需要 \\card <位置> <id> 或 \\card <id> <数量>）" % arg
	else:
		var p3 := _card_cmd_canonical_position(bits[0])
		if p3 == "":
			return "未知位置「%s」。使用 hand / deck / draw / discard / exhaust" % bits[0]
		if bits.size() > 3:
			return "参数过多（最多：位置 id 数量）。"
		where = p3
		card_id = bits[1]
		if bits.size() >= 3:
			if not bits[2].is_valid_int():
				return "数量须为正整数：%s" % bits[2]
			count = clampi(int(bits[2]), 1, 99)

	if not in_battle and where != "deck":
		return "战斗外仅允许向 deck 添加（\\card deck <id> [数量]）。"

	var path := _find_card_tres_path(card_id)
	if path.is_empty():
		return "找不到 id 为「%s」的卡牌 .tres" % card_id
	var card_res: Resource = ResourceLoader.load(path)
	if card_res == null or not (card_res is Card):
		return "加载失败或不是 Card：%s" % path

	var pile: CardPile = null
	var hand: Hand = null
	match where:
		"deck":
			pile = cs.deck
		"draw", "discard", "exhaust":
			if not in_battle:
				return "战斗外无法向 %s 添加。" % where
			var bcs: CharacterStats = bt.get("char_stats") as CharacterStats
			if bcs == null:
				return "战斗中无 CharacterStats。"
			match where:
				"draw":
					pile = bcs.draw_pile
				"discard":
					pile = bcs.discard
				"exhaust":
					pile = bcs.exhaust
		"hand":
			if not in_battle:
				return "战斗外无法向 hand 添加。"
			var bu: BattleUI = bt.get("battle_ui") as BattleUI
			if bu == null:
				return "BattleUI 未就绪。"
			hand = bu.hand
			if hand == null:
				return "Hand 未就绪。"

	var cname := (card_res as Card).get_display_name()
	var wlabel := _card_cmd_where_label(where)
	for _i in range(count):
		var inst: Card = (card_res as Card).duplicate(true) as Card
		match where:
			"deck", "draw", "discard", "exhaust":
				pile.add_card(inst)
			"hand":
				hand.add_card(inst)

	if where == "deck":
		return "已向牌库添加 %d×「%s」（%s）；战斗中本场抽牌堆不变，之后场次生效。" % [count, cname, path]
	return "已向%s添加 %d×「%s」（%s）" % [wlabel, count, cname, path]


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


## 同步版本：仅用于查询，添加操作请使用 _cmd_relic_async
func _cmd_relic(arg: String) -> String:
	return "请通过命令行使用 \\relic 命令"


## 异步版本：使用 add_relic_async 触发遗物的 pickup 效果
func _cmd_relic_async(arg: String) -> String:
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
	## 使用异步添加，确保触发遗物的 pickup 效果（如无上宝石的选牌升级）
	await rh.add_relic_async(inst)
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


func _cmd_win(_arg: String) -> String:
	## 检查是否在战斗中
	var bt := _current_battle()
	if bt == null:
		return "\\win 只能在战斗中使用。"
	
	## 获取战斗场景并强制胜利
	var battle := bt as Battle
	if battle == null:
		return "无法获取战斗场景。"
	
	## 触发战斗胜利
	battle.debug_force_win()
	return "已触发战斗胜利！"


func _cmd_help() -> String:
	return """可用指令：
战斗中：\\enemy <id> | \\card <位置> <id> [数量] | \\health <数值> | \\win
任意时刻：\\event <id> | \\relic add/delete <id> | \\jump [on/off] | \\help"""


var _jump_mode: bool = false

func _cmd_jump(arg: String) -> String:
	_ensure_run()
	if _run == null or not is_instance_valid(_run):
		return "无法获取 Run 节点。"
	
	var map := _run.map
	if map == null or not is_instance_valid(map):
		return "当前不在地图界面。"
	
	## 切换模式
	if arg.strip_edges().to_lower() == "off" or (arg.is_empty() and _jump_mode):
		_jump_mode = false
		## 恢复正常解锁逻辑：先锁定所有房间，再正常解锁
		for map_room in map.rooms.get_children():
			if "available" in map_room:
				map_room.available = false
		if map.floors_climbed > 0:
			map.unlock_next_rooms()
		else:
			map.unlock_floor()
		return "\\jump 已关闭，恢复正常路线限制。"
	else:
		_jump_mode = true
		## 解锁所有房间（检查是否有 available 属性）
		for map_room in map.rooms.get_children():
			if "available" in map_room:
				map_room.available = true
		return "\\jump 已开启，现在可以自由选择任何房间。再次输入 \\jump 关闭。"


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
