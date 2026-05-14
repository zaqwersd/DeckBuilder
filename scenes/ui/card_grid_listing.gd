class_name CardGridListing
extends CardPreviewListHover

## 卡牌系列视图（牌库/牌堆/选牌/升级等）共用基类：五列网格、悬停 1.1、词条 tooltip、点击由子类处理。
const CARD_MENU_UI_SCENE := preload("res://scenes/ui/card_menu_ui.tscn")
const LISTING_GRID_COLUMNS := 5


## 子类复写：返回用于平铺 CardMenuUI 的 GridContainer；无网格（如仅居中单卡）则返回 null。
func get_card_listing_grid() -> GridContainer:
	return null


func configure_listing_grid_defaults(grid: GridContainer) -> void:
	if grid == null:
		return
	grid.columns = LISTING_GRID_COLUMNS


static func make_listing_card_menu() -> CardMenuUI:
	var menu := CARD_MENU_UI_SCENE.instantiate() as CardMenuUI
	menu.use_listing_hover_zoom = true
	menu.mouse_filter = Control.MOUSE_FILTER_STOP
	menu.call_deferred("refresh_listing_hover_pivot")
	return menu


func create_listing_card_menu() -> CardMenuUI:
	return make_listing_card_menu()


func gather_listing_card_menus_for_keyword_tooltip() -> Array[CardMenuUI]:
	var g := get_card_listing_grid()
	if g == null:
		return []
	var out: Array[CardMenuUI] = []
	for ch in g.get_children():
		if ch is CardMenuUI:
			out.append(ch as CardMenuUI)
	return out


func _ready() -> void:
	super._ready()
	var g := get_card_listing_grid()
	if g:
		configure_listing_grid_defaults(g)
