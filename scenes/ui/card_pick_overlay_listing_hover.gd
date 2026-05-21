extends CardPreviewListHover

## 挂在 CardPickOverlay 的 Content 上，驱动候选卡牌的词条 tooltip（局外列表，含黄/红/灰说明）。
@onready var _cards: GridContainer = %Cards


func gather_listing_card_menus_for_keyword_tooltip() -> Array[CardMenuUI]:
	var out: Array[CardMenuUI] = []
	if _cards == null:
		return out
	for ch in _cards.get_children():
		if ch is CardMenuUI:
			out.append(ch as CardMenuUI)
	return out
