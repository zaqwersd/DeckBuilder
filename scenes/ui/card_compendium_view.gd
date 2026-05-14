class_name CardCompendiumView
extends CardPileView

## 主菜单图鉴：按类别列出全部卡各一张（稀有度排序）；点击打开升级预览（只读）。

enum Category { BLADE, COMMON }

var _category_tabs: HBoxContainer
var _current_category: Category = Category.BLADE
var _tab_entries: Array[Dictionary] = []


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_cleanup_compendium_modal_on_hide()


func _cleanup_compendium_modal_on_hide() -> void:
	set_deck_upgrade_preview_blocks_pile_input(false)
	Events.card_keyword_tooltip_hide.emit()
	var host := get_tree().get_first_node_in_group("main_menu") as Node
	if host == null:
		return
	var layer := host.get_node_or_null("CompendiumUpgradeModalLayer")
	if layer == null:
		return
	for ch: Node in layer.get_children():
		if is_instance_valid(ch):
			ch.queue_free()


func _ready() -> void:
	super._ready()
	title.text = "卡牌图鉴"
	_category_tabs = get_node_or_null("%CategoryTabs") as HBoxContainer
	if _category_tabs:
		_category_tabs.mouse_filter = Control.MOUSE_FILTER_STOP
		_build_category_tabs()
	_refresh_category_tabs_visual()
	_refresh_compendium_grid()


func _build_category_tabs() -> void:
	for c in _category_tabs.get_children():
		c.queue_free()
	_tab_entries.clear()
	_tab_entries.append(_make_tab_entry("剑客", Category.BLADE))
	_tab_entries.append(_make_tab_entry("公共", Category.COMMON))


func _make_tab_entry(label_text: String, cat: Category) -> Dictionary:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(132, 52)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var lab := Label.new()
	lab.text = label_text
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.set_anchors_preset(Control.PRESET_FULL_RECT)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.add_theme_font_size_override("font_size", 22)
	panel.add_child(lab)
	## gui_input 的信号参数在前、bind 在后，勿用 bind(cat) 否则第一个参数会变成 InputEvent 触发类型错误。
	var cat_captured := cat
	panel.gui_input.connect(
		func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_select_category(cat_captured)
	)
	_category_tabs.add_child(panel)
	return {"panel": panel, "category": cat}


func _select_category(cat: Category) -> void:
	if cat == _current_category:
		return
	_current_category = cat
	_refresh_category_tabs_visual()
	_refresh_compendium_grid()


func _refresh_category_tabs_visual() -> void:
	for e: Dictionary in _tab_entries:
		var p: Panel = e.get("panel") as Panel
		var cat: Category = e.get("category") as Category
		if not is_instance_valid(p):
			continue
		var active := cat == _current_category
		p.add_theme_stylebox_override("panel", _tab_style_for(cat, active))


func _tab_style_for(cat: Category, active: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(0)
	match cat:
		Category.BLADE:
			s.bg_color = Color(0.0, 150.0 / 255.0, 136.0 / 255.0, 1.0) if active else Color(0.0, 118.0 / 255.0, 106.0 / 255.0, 1.0)
			s.border_color = Color(0.55, 0.95, 0.88, 1.0) if active else Color(0.12, 0.35, 0.32, 1.0)
		Category.COMMON:
			s.bg_color = Color(97.0 / 255.0, 97.0 / 255.0, 97.0 / 255.0, 1.0) if active else Color(72.0 / 255.0, 72.0 / 255.0, 72.0 / 255.0, 1.0)
			s.border_color = Color(0.75, 0.75, 0.75, 1.0) if active else Color(0.35, 0.35, 0.35, 1.0)
	s.set_border_width_all(3 if active else 1)
	return s


func _refresh_compendium_grid() -> void:
	var sc := cards.get_parent() as ScrollContainer
	if sc:
		sc.scroll_vertical = 0
	for n: Node in cards.get_children():
		n.queue_free()
	var list := _cards_for_category(_current_category)
	for card: Card in list:
		var new_card := create_listing_card_menu()
		cards.add_child(new_card)
		new_card.visuals.number_bbcode_style = number_bbcode_style
		new_card.card = card
		var menu_ref := new_card
		new_card.card_pick_pressed.connect(func(_picked: Card) -> void: _on_deck_card_pick_for_preview(menu_ref))
		_apply_pile_card_transform(new_card)
	if not is_equal_approx(display_scale, 1.0):
		cards.add_theme_constant_override("v_separation", int(round(36.0 * display_scale)))
	else:
		cards.remove_theme_constant_override("v_separation")
	show()


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


static func _sort_rarity_then_id(a: Card, b: Card) -> bool:
	if a.rarity != b.rarity:
		return a.rarity < b.rarity
	return String(a.id) < String(b.id)


func _cards_for_category(cat: Category) -> Array[Card]:
	var folder := ""
	match cat:
		Category.BLADE:
			folder = "res://characters/blade/cards"
		Category.COMMON:
			folder = "res://common_cards"
	var paths := _list_card_tres_paths(folder)
	var by_id: Dictionary = {}
	for p: String in paths:
		var res := load(p)
		if res == null or not (res is Card):
			continue
		var template := res as Card
		if by_id.has(template.id):
			continue
		by_id[template.id] = template.duplicate(true) as Card
	var out: Array[Card] = []
	for k: Variant in by_id.keys():
		out.append(by_id[k] as Card)
	out.sort_custom(_sort_rarity_then_id)
	return out


func _run_deck_upgrade_preview(card: Card) -> void:
	if card == null:
		return
	var host := get_tree().get_first_node_in_group("main_menu") as Control
	if host == null:
		host = get_tree().current_scene as Control
	if host == null:
		return
	var layer := host.get_node_or_null("CompendiumUpgradeModalLayer") as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "CompendiumUpgradeModalLayer"
		layer.layer = 85
		host.add_child(layer)
	set_deck_upgrade_preview_blocks_pile_input(true)
	var flow := CARD_UPGRADE_FLOW.instantiate() as CardUpgradeFlow
	layer.add_child(flow)
	flow.begin_preview(card)
	await flow.finished
	set_deck_upgrade_preview_blocks_pile_input(false)
	if is_instance_valid(flow):
		flow.queue_free()
