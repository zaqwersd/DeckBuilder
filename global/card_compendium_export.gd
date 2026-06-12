class_name CardCompendiumExport
extends RefCounted

## 命令行 / 工具：收集图鉴卡牌并离屏渲染左右对比长图。

enum Category { BLADE, COMMON }

const BLADE_FOLDER := "res://characters/blade/cards"
const COMMON_FOLDER := "res://common_cards"

const EXPORT_MARGIN := 45
const PANEL_GAP := 32
const GRID_V_SEPARATION := 36
const TITLE_FONT_SIZE := 54
const SECTION_FONT_SIZE := 28
const BG_COLOR := Color(0.12, 0.12, 0.14, 1.0)
const PANEL_MIN_WIDTH := 1340.0
const LOG_CARD_MARGIN := 24

const RARITY_DISPLAY_NAMES := {
	Card.Rarity.STARTER: "起手",
	Card.Rarity.COMMON: "普通",
	Card.Rarity.UNCOMMON: "罕见",
	Card.Rarity.RARE: "稀有",
	Card.Rarity.SPECIAL: "特殊",
}


static func category_from_cli_name(name: String) -> int:
	match name.strip_edges().to_lower():
		"blade", "剑客":
			return Category.BLADE
		"common", "公共":
			return Category.COMMON
		_:
			return -1


static func category_display_name(cat: Category) -> String:
	match cat:
		Category.BLADE:
			return "剑客"
		Category.COMMON:
			return "公共"
		_:
			return "未知"


static func category_folder(cat: Category) -> String:
	match cat:
		Category.BLADE:
			return BLADE_FOLDER
		Category.COMMON:
			return COMMON_FOLDER
		_:
			return ""


static func cards_for_category(cat: Category) -> Array[Card]:
	var folder := category_folder(cat)
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
	out.sort_custom(CardGridListing.sort_rarity_then_id)
	return out


static func card_display_copy(template: Card, upgraded: bool) -> Card:
	var display := template.duplicate(true) as Card
	if upgraded:
		display.apply_upgrade()
	return display


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


static func default_output_path(cat: Category) -> String:
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("T", "_")
	var cat_slug := "blade" if cat == Category.BLADE else "common"
	return "user://exports/card_compendium_%s_%s.png" % [cat_slug, stamp]


static func default_log_path_for(cat: Category) -> String:
	var cat_slug := "blade" if cat == Category.BLADE else "common"
	return "res://card_compendium_%s.md" % cat_slug


static func default_log_images_dir_for(cat: Category) -> String:
	var cat_slug := "blade" if cat == Category.BLADE else "common"
	return "res://card_compendium_%s_images" % cat_slug


static func listing_description_bbcode(card: Card) -> String:
	if card == null:
		return ""
	Card.push_visual_number_bbcode_style(Card.NumberBbcodeStyle.LISTING_PLAIN)
	var raw := card.get_updated_visual_description_bbcode(null, null, null)
	Card.pop_visual_number_bbcode_style()
	raw = _prepend_intrinsic_line_bbcode(card, raw)
	return CardUpgradeUiColors.strip_listing_highlight_bbcode(raw)


static func card_meta_line(card: Card) -> String:
	if card == null:
		return ""
	var type_name: String = CardVisualsBase.TYPE_DISPLAY.get(card.type, "")
	var rarity_name: String = RARITY_DISPLAY_NAMES.get(card.rarity, str(card.rarity))
	var cost_text := "X" if card.is_x_cost() else str(card.cost)
	return "%s · %s · 费用 %s · %s" % [type_name, rarity_name, cost_text, card.id]


static func bbcode_to_plain_text(bbcode: String) -> String:
	var text := bbcode
	text = text.replace("[br]", "\n")
	text = text.replace("[center]", "").replace("[/center]", "")
	var url_re := RegEx.new()
	url_re.compile("\\[url=[^\\]]+\\](.*?)\\[/url\\]")
	text = url_re.sub(text, "$1", true)
	var tag_re := RegEx.new()
	tag_re.compile("\\[/?[^\\]]+\\]")
	text = tag_re.sub(text, "", true)
	return text.strip_edges()


static func card_log_text_paragraph(base: Card, upgraded: Card) -> String:
	var base_desc := bbcode_to_plain_text(listing_description_bbcode(base))
	var up_desc := bbcode_to_plain_text(listing_description_bbcode(upgraded))
	if up_desc == base_desc:
		return base_desc
	return "%s\n\n升级后：%s" % [base_desc, up_desc]


static func log_image_markdown_ref(images_dir_res: String, card_id: String) -> String:
	return "%s/%s.png" % [images_dir_res.trim_prefix("res://").trim_suffix("/"), card_id]


static func _prepend_intrinsic_line_bbcode(card: Card, raw: String) -> String:
	if card.intrinsic:
		return CardKeywordTokens.bb_mechanic_link("固有。", "intrinsic") + "[br]" + raw
	for track_id in card.get_upgrade_track_ids():
		if track_id == "intrinsic_line":
			return CardKeywordTokens.bb_mechanic_link("固有。", "intrinsic") + "[br]" + raw
	return raw


static func ensure_parent_dir_for(path: String) -> Error:
	var abs := ProjectSettings.globalize_path(path)
	var parent := abs.get_base_dir()
	if parent.is_empty():
		return ERR_INVALID_PARAMETER
	if DirAccess.dir_exists_absolute(parent):
		return OK
	return DirAccess.make_dir_recursive_absolute(parent)


class ExportRunner extends Node:
	func run_export(
		cat: CardCompendiumExport.Category,
		output_path: String,
		log_path: String = "",
	) -> void:
		var templates := CardCompendiumExport.cards_for_category(cat)
		if templates.is_empty():
			push_error("No cards found for category.")
			_finish(1)
			return
		var label := CardCompendiumExport.category_display_name(cat)
		var image := await _render_category_compare_image(templates, label)
		if image == null:
			push_error("Failed to render compendium image.")
			_finish(1)
			return
		var err := CardCompendiumExport.ensure_parent_dir_for(output_path)
		if err != OK:
			push_error("Failed to create output directory: %s" % error_string(err))
			_finish(1)
			return
		err = image.save_png(output_path)
		if err != OK:
			push_error("Failed to save PNG: %s" % error_string(err))
			_finish(1)
			return
		print("Exported: %s" % ProjectSettings.globalize_path(output_path))

		if log_path.is_empty():
			log_path = CardCompendiumExport.default_log_path_for(cat)
		err = await _export_category_log(templates, label, log_path, cat)
		if err != OK:
			_finish(1)
			return
		print("Exported log: %s" % ProjectSettings.globalize_path(log_path))
		_finish(0)


	func _export_category_log(
		templates: Array[Card],
		category_label: String,
		log_path: String,
		cat: CardCompendiumExport.Category,
	) -> int:
		var images_dir := CardCompendiumExport.default_log_images_dir_for(cat)
		var err := CardCompendiumExport.ensure_parent_dir_for(log_path)
		if err != OK:
			push_error("Failed to create log directory: %s" % error_string(err))
			return err
		err = CardCompendiumExport.ensure_parent_dir_for("%s/.keep" % images_dir)
		if err != OK:
			push_error("Failed to create image directory: %s" % error_string(err))
			return err
		var sections: PackedStringArray = []
		for template: Card in templates:
			var section := await _build_card_log_section(template, images_dir)
			if section.is_empty():
				push_error("Failed to build log section for %s" % template.id)
				return ERR_CANT_CREATE
			sections.append(section)
		var md := "# 卡牌图鉴 · %s\n\n%s\n" % [category_label, "\n\n".join(sections)]
		var f := FileAccess.open(log_path, FileAccess.WRITE)
		if f == null:
			push_error("Failed to write log: %s" % log_path)
			return ERR_CANT_CREATE
		f.store_string(md)
		return OK


	func _build_card_log_section(template: Card, images_dir_res: String) -> String:
		var base := CardUpgradeFlow._unupgraded_card_for_compare(template)
		if base == null:
			return ""
		var upgraded := base.duplicate(true) as Card
		upgraded.apply_upgrade()
		var card_img := await _render_single_card_image(base)
		if card_img == null:
			return ""
		var img_path := "%s/%s.png" % [images_dir_res.trim_suffix("/"), base.id]
		var img_err := CardCompendiumExport.ensure_parent_dir_for(img_path)
		if img_err != OK:
			return ""
		if card_img.save_png(img_path) != OK:
			return ""
		var img_ref := CardCompendiumExport.log_image_markdown_ref(images_dir_res, base.id)
		var display_name := base.get_display_name()
		var body := CardCompendiumExport.card_log_text_paragraph(base, upgraded)
		return (
			"## %s\n\n![%s](%s)\n\n%s\n\n%s"
			% [display_name, display_name, img_ref, CardCompendiumExport.card_meta_line(base), body]
		)


	func _render_single_card_image(card: Card) -> Image:
		var subvp := SubViewport.new()
		subvp.disable_3d = true
		subvp.transparent_bg = false
		subvp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(subvp)

		var root := Control.new()
		root.set_anchors_preset(Control.PRESET_TOP_LEFT)
		subvp.add_child(root)

		var bg := ColorRect.new()
		bg.color = CardCompendiumExport.BG_COLOR
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.add_child(bg)

		var margin := MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
		margin.add_theme_constant_override("margin_left", CardCompendiumExport.LOG_CARD_MARGIN)
		margin.add_theme_constant_override("margin_top", CardCompendiumExport.LOG_CARD_MARGIN)
		margin.add_theme_constant_override("margin_right", CardCompendiumExport.LOG_CARD_MARGIN)
		margin.add_theme_constant_override("margin_bottom", CardCompendiumExport.LOG_CARD_MARGIN)
		root.add_child(margin)

		var center := CenterContainer.new()
		margin.add_child(center)
		var menu := CardGridListing.make_listing_card_menu()
		menu.use_listing_hover_zoom = false
		menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
		menu.card = card
		center.add_child(menu)

		return await _capture_subviewport(subvp, root, margin, CardCompendiumExport.LOG_CARD_MARGIN)


	func _capture_subviewport(
		subvp: SubViewport,
		root: Control,
		margin: MarginContainer,
		outer_pad: float = CardCompendiumExport.LOG_CARD_MARGIN,
	) -> Image:
		for _i in 3:
			await get_tree().process_frame
		_sync_all_card_fonts(root)
		for _i in 3:
			await get_tree().process_frame
		var content_size := margin.get_combined_minimum_size() + Vector2(
			outer_pad * 2.0,
			outer_pad * 2.0
		)
		var w := maxi(1, int(ceil(content_size.x)))
		var h := maxi(1, int(ceil(content_size.y)))
		subvp.size = Vector2i(w, h)
		root.size = Vector2(w, h)
		subvp.render_target_update_mode = SubViewport.UPDATE_ONCE
		for _i in 4:
			await get_tree().process_frame
		var tex := subvp.get_texture()
		if tex == null:
			subvp.queue_free()
			return null
		var image := tex.get_image()
		subvp.queue_free()
		return image


	func _finish(code: int) -> void:
		get_tree().quit(code)


	func _render_category_compare_image(templates: Array[Card], category_label: String) -> Image:
		var subvp := SubViewport.new()
		subvp.disable_3d = true
		subvp.transparent_bg = false
		subvp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(subvp)

		var root := Control.new()
		root.set_anchors_preset(Control.PRESET_TOP_LEFT)
		subvp.add_child(root)

		var bg := ColorRect.new()
		bg.color = CardCompendiumExport.BG_COLOR
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.add_child(bg)

		var margin := MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
		margin.add_theme_constant_override("margin_left", CardCompendiumExport.EXPORT_MARGIN)
		margin.add_theme_constant_override("margin_top", CardCompendiumExport.EXPORT_MARGIN)
		margin.add_theme_constant_override("margin_right", CardCompendiumExport.EXPORT_MARGIN)
		margin.add_theme_constant_override("margin_bottom", CardCompendiumExport.EXPORT_MARGIN)
		root.add_child(margin)

		var outer_vbox := VBoxContainer.new()
		outer_vbox.add_theme_constant_override("separation", 24)
		margin.add_child(outer_vbox)

		var title := _make_title_label("卡牌图鉴 · %s" % category_label, CardCompendiumExport.TITLE_FONT_SIZE)
		outer_vbox.add_child(title)

		var panels := HBoxContainer.new()
		panels.add_theme_constant_override("separation", CardCompendiumExport.PANEL_GAP)
		outer_vbox.add_child(panels)

		var left_panel := _build_card_panel("未升级", false, templates)
		var right_panel := _build_card_panel("已升级", true, templates)
		panels.add_child(left_panel)
		panels.add_child(right_panel)

		return await _capture_subviewport(subvp, root, margin)


	func _build_card_panel(section_title: String, upgraded: bool, templates: Array[Card]) -> VBoxContainer:
		var panel := VBoxContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.custom_minimum_size.x = CardCompendiumExport.PANEL_MIN_WIDTH
		panel.add_theme_constant_override("separation", 12)

		var section := _make_title_label(section_title, CardCompendiumExport.SECTION_FONT_SIZE)
		panel.add_child(section)

		var grid := GridContainer.new()
		grid.columns = CardGridListing.LISTING_GRID_COLUMNS
		grid.add_theme_constant_override("h_separation", 0)
		grid.add_theme_constant_override("v_separation", CardCompendiumExport.GRID_V_SEPARATION)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_child(grid)

		for template: Card in templates:
			var menu := CardGridListing.make_listing_card_menu()
			menu.use_listing_hover_zoom = false
			menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
			menu.card = CardCompendiumExport.card_display_copy(template, upgraded)
			grid.add_child(menu)
		return panel


	func _make_title_label(text: String, font_size: int) -> Label:
		var lab := Label.new()
		lab.text = text
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_font_size_override("font_size", font_size)
		return lab


	func _sync_all_card_fonts(node: Node) -> void:
		if node is CardMenuUI:
			var menu := node as CardMenuUI
			if is_instance_valid(menu.visuals):
				menu.visuals.apply_minimum_fonts_once_then_freeze_for_phantom()
		for ch in node.get_children():
			_sync_all_card_fonts(ch)

