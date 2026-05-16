extends Node

## 本场战斗已形成终局（玩家死亡或场上已无存活敌人）。抽牌/弃牌/飞牌等协程应短路，避免对已释放节点做动画。
var combat_ended: bool = false


func reset_combat_flow() -> void:
	combat_ended = false
	_attack_card_effect_depth = 0


var _attack_card_effect_depth: int = 0


func begin_attack_card_effects() -> void:
	_attack_card_effect_depth += 1


func end_attack_card_effects() -> void:
	_attack_card_effect_depth = maxi(0, _attack_card_effect_depth - 1)


func is_inside_attack_card_effects() -> bool:
	return _attack_card_effect_depth > 0


func mark_combat_ended() -> void:
	combat_ended = true


func is_combat_ended() -> bool:
	return combat_ended


## 全屏/叠层 UI：仅栈顶子树响应「几何悬停」类交互（手牌抬起、列表 1.1 倍、列表词条 tooltip）。
## 由 CardPileView / CardUpgradeFlow / DeckPickerOverlay / CardRewards 等在显示时 push，关闭时 pop。
var _pointer_exclusive_stack: Array[Node] = []


func begin_pointer_exclusive_ui(owner: Node) -> void:
	if owner == null:
		return
	if not _pointer_exclusive_stack.is_empty() and _pointer_exclusive_stack.back() == owner:
		return
	_pointer_exclusive_stack.append(owner)


func end_pointer_exclusive_ui(owner: Node) -> void:
	if owner == null:
		return
	var idx := _pointer_exclusive_stack.rfind(owner)
	if idx < 0:
		return
	if idx == _pointer_exclusive_stack.size() - 1:
		_pointer_exclusive_stack.pop_back()
		return
	_pointer_exclusive_stack.remove_at(idx)


func get_pointer_exclusive_leaf() -> Node:
	if _pointer_exclusive_stack.is_empty():
		return null
	return _pointer_exclusive_stack[_pointer_exclusive_stack.size() - 1]


func _effective_canvas_layer(n: Node) -> int:
	var x: Node = n
	while is_instance_valid(x):
		if x is CanvasLayer:
			return (x as CanvasLayer).layer
		x = x.get_parent()
	return 0


func effective_canvas_layer_of(node: Node) -> int:
	return _effective_canvas_layer(node)


## 当存在独占层且 `control` 不在该层子树内时，应跳过悬停/缩放/tooltip（仍可用 gui 命中挡住点击）。
func is_pointer_ui_obscured_for(control: Node) -> bool:
	# 清理已失效的节点（保险机制）
	while not _pointer_exclusive_stack.is_empty():
		var raw_top: Variant = _pointer_exclusive_stack.back()
		if typeof(raw_top) != TYPE_OBJECT or raw_top == null:
			_pointer_exclusive_stack.pop_back()
			continue
		var top: Node = raw_top as Node
		if not is_instance_valid(top) or not top.is_inside_tree():
			_pointer_exclusive_stack.pop_back()
		else:
			break

	var leaf := get_pointer_exclusive_leaf()
	if leaf == null or not is_instance_valid(leaf):
		return false
	if leaf == control:
		return false
	if leaf.is_ancestor_of(control):
		return false
	var ll := _effective_canvas_layer(leaf)
	var cl := _effective_canvas_layer(control)
	if cl != ll:
		return cl < ll
	## 同 CanvasLayer：独占叶一般为后叠上的全屏/模态（如升级叠在选牌上），非子孙的一律视为在下层。
	return true


# Card-related events
signal card_drag_started(card_ui: CardUI)
signal card_drag_ended(card_ui: CardUI)
signal card_aim_started(card_ui: CardUI)
signal card_aim_ended(card_ui: CardUI)
signal card_played(card: Card)
## 牌进入消耗堆（打出消耗、虚无、被效果消耗等统一入口）。
signal card_exhausted(card: Card)
## 玩家状态栏层数变化（如巨剑）：手牌需刷新攻击牌实际耗能显示。
signal player_hand_cost_context_changed

# Player-related events
signal player_hand_drawn
signal player_hand_discarded
signal player_turn_ended
signal player_hit
signal player_died

# Enemy-related events
signal enemy_action_completed(enemy: Enemy)
signal enemy_turn_ended
signal enemy_died(enemy: Enemy)

# Battle-related events
signal battle_over_screen_requested(text: String, type: BattleOverPanel.Type)
signal battle_won
signal status_tooltip_requested(statuses: Array[Status])
## 战斗/地图：悬停在单个状态图标上显示说明；open_to_right 为 true 时框在图标右侧（玩家），false 时在左侧（敌人）
signal status_tooltip_hover_show(status: Status, near_to: Control, open_to_right: bool)
signal status_tooltip_hover_hide
## 战斗：悬停在敌人意图条（IntentUI）上；`bbcode` 与 `StatusHoverTooltip` 正文格式一致。
signal intent_tooltip_hover_show(bbcode: String, near_to: Control, open_to_right: bool)
signal intent_tooltip_hover_hide

## 卡面描述中「虚无」「消耗」「易伤」「力量」等词条悬停（可多段垂直排列）
signal card_keyword_tooltip_show(ids: PackedStringArray, near_to: Control)
signal card_keyword_tooltip_hide
## 词条链接悬停时请求刷新 tooltip（由 Hand 统一显示所有词条）
signal card_keyword_tooltip_refresh_requested(from_visuals: Control)
## 由 CardKeywordTooltip 在 show/hide 时同步，供 Hand 检测渲染 abort 后的自愈
var card_keyword_tooltip_visible := false
var card_keyword_tooltip_render_pending := false

# Map-related events
signal map_exited(room: Room)

# Shop-related events
signal shop_entered(shop: Shop)
signal shop_relic_bought(relic: Relic, gold_cost: int)
signal shop_card_bought(card: Card, gold_cost: int, from_control: Control)
signal shop_exited

# Campfire-related events
signal campfire_exited

# Battle Reward-related events
signal battle_reward_exited

# Treasure Room-related events
signal treasure_room_exited(found_relic: Relic)

# Relic-related事件：悬停显示说明；near_to 用于把提示框摆在遗物旁（RelicUI 等 Control）
signal relic_tooltip_hover_show(relic: Relic, near_to: Control)
signal relic_tooltip_hover_hide

# Random Event room-related events
signal event_room_exited
