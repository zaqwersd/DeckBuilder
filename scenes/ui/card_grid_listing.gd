class_name CardGridListing
extends CardPreviewListHover

## 卡牌系列视图（牌库/牌堆/选牌/升级等）共用基类：五列网格、悬停 1.1、词条 tooltip、点击由子类处理。
const CARD_MENU_UI_SCENE := preload("res://scenes/ui/card_menu_ui.tscn")
const LISTING_GRID_COLUMNS := 5


## 子类复写：返回用于平铺 CardMenuUI 的 GridContainer；无网格（如仅居中单卡）则返回 null。
func get_card_listing_grid() -> GridContainer:
	return null


static func configure_listing_grid_defaults(grid: GridContainer) -> void:
	if grid == null:
		return
	grid.columns = LISTING_GRID_COLUMNS


## 稀有度 → 类型（攻/技/能/态）→ id。
static func sort_rarity_then_id(a: Card, b: Card) -> bool:
	if a.rarity != b.rarity:
		return a.rarity < b.rarity
	if a.type != b.type:
		return a.type < b.type
	return String(a.id) < String(b.id)


## 图鉴专用：非状态牌先按稀有度排序，状态牌统一排在最后并按 id 排序。
static func sort_compendium_listing(a: Card, b: Card) -> bool:
	var a_status := a.type == Card.Type.STATUS
	var b_status := b.type == Card.Type.STATUS
	if a_status != b_status:
		return not a_status
	if a_status:
		return String(a.id) < String(b.id)
	return sort_rarity_then_id(a, b)


## 图鉴展示：状态牌统一为 STATUSES 稀有度（边框 #607d8b）。
static func apply_compendium_display_overrides(card: Card) -> void:
	if card != null and card.type == Card.Type.STATUS:
		card.rarity = Card.Rarity.STATUSES


static func sorted_card_entries(cards: Array[Card]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(cards.size()):
		out.append({"card": cards[i], "index": i})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return sort_rarity_then_id(a["card"] as Card, b["card"] as Card)
	)
	return out


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
