class_name BattleReward
extends Control

const REWARD_BUTTON = preload("res://scenes/ui/reward_button.tscn")
const GOLD_ICON := preload("res://art/gold.png")
const GOLD_TEXT := "%s 金币"
const CARD_ICON := preload("res://art/rarity.png")
const CARD_TEXT := "添加新卡牌"
const UPGRADE_ICON := preload("res://art/tile_0074.png")
const UPGRADE_TEXT := "升级一张牌"

## 卡牌奖励升级概率（已移至 RunStats 动态计算）

@export var run_stats: RunStats
@export var character_stats: CharacterStats
@export var relic_handler: RelicHandler

@onready var rewards: VBoxContainer = %Rewards

## 奖励状态追踪
var _gold_amount: int = 0
var _gold_taken: bool = false
var _relics: Array[Relic] = []
var _relics_taken: Array[bool] = []
var _cards_taken: bool = false
var _card_reward_offered: bool = false
var _card_reward_ids: PackedStringArray = PackedStringArray()
var _upgrade_offered: bool = false
var _upgrade_taken: bool = false
var _upgrade_flow_active: bool = false
var _is_reload: bool = false


func _ready() -> void:
	for node: Node in rewards.get_children():
		node.queue_free()
	
	## 设置与当前层数匹配的背景图
	_setup_background()


## 从 Run 初始化奖励状态
func setup_from_run(is_reload: bool) -> void:
	_is_reload = is_reload
	if is_reload:
		_restore_reward_state_from_save()
	## 非重载时：由外部调用 add_*_reward 添加奖励，最后调用 save_initial_state 保存


## 设置与当前层数匹配的背景图
func _setup_background() -> void:
	var bg_rect := $Background as TextureRect
	if bg_rect == null:
		return
	
	var run := get_tree().get_first_node_in_group("run") as Run
	if run == null:
		return
	
	## 根据当前层数设置对应背景图
	match run.current_act:
		1:
			bg_rect.texture = preload("res://art/act1_background.png")
		2:
			bg_rect.texture = preload("res://art/act2_background.png")
		3:
			bg_rect.texture = preload("res://art/act3_background.png")
		_:
			bg_rect.texture = preload("res://art/background.png")


## 保存奖励初始状态到存档（在所有奖励添加完成后调用）
func save_initial_state() -> void:
	var run := get_tree().get_first_node_in_group("run") as Run
	if run == null:
		return
	## 收集当前待添加的遗物
	var relics_to_save: Array[Relic] = []
	for r: Relic in _relics:
		relics_to_save.append(r)
	print("[BattleReward] 保存初始奖励状态: gold=", _gold_amount, " relics=", relics_to_save.size())
	## 保存并退出需能恢复「有选牌按钮」；普通战在点按钮前也要先 roll 并写入 pending，避免读档丢奖励。
	if _card_reward_offered and _card_reward_ids.is_empty():
		_roll_or_restore_card_rewards()
	run.persist_battle_reward_full_state(
		_gold_amount, relics_to_save, _card_reward_offered, _upgrade_offered
	)


## 从存档恢复奖励状态
func _restore_reward_state_from_save() -> void:
	var run := get_tree().get_first_node_in_group("run") as Run
	if run == null:
		return
	var state := run.get_battle_reward_state()
	if state.is_empty():
		return
	
	_gold_amount = state.get("gold", 0)
	_card_reward_ids = state.get("card_ids", PackedStringArray())
	_card_reward_offered = bool(state.get("card_offered", false))
	if not _card_reward_offered and not _card_reward_ids.is_empty():
		_card_reward_offered = true
	_upgrade_offered = bool(state.get("upgrade_offered", false))
	if _upgrade_offered and not _deck_has_upgradeable_card():
		_auto_skip_card_upgrade_reward_if_deck_fully_upgraded()
	
	## 恢复遗物列表（但强制标记为未领取，实现"回到战斗刚结束"的效果）
	var relic_ids: PackedStringArray = state.get("relic_ids", PackedStringArray())
	_relics.clear()
	_relics_taken.clear()
	
	for i: int in range(relic_ids.size()):
		var relic_id: String = relic_ids[i]
		var relic: Relic = GameContent.load_relic_template(relic_id)
		if relic != null:
			_relics.append(relic)
			_relics_taken.append(false)  # 强制为未领取
	
	## 强制重置所有奖励为未领取状态
	_gold_taken = false
	_cards_taken = false
	_upgrade_taken = false
	
	## 重置存档中的领取状态，确保下次保存也是未领取
	run.save_data.battle_reward_gold_taken = false
	run.save_data.battle_reward_cards_taken = false
	run.save_data.battle_reward_upgrade_taken = false
	for i: int in range(run.save_data.battle_reward_relics_taken.size()):
		run.save_data.battle_reward_relics_taken[i] = 0
	
	## 根据恢复的状态重新构建UI
	_rebuild_reward_ui()


## 根据当前状态重建奖励UI
func _rebuild_reward_ui() -> void:
	## 清除现有按钮
	for node: Node in rewards.get_children():
		node.queue_free()
	
	## 添加金币奖励（如果未领取）
	if _gold_amount > 0 and not _gold_taken:
		_add_gold_reward_button(_gold_amount)
	
	## 添加遗物奖励（如果未领取）
	for i: int in range(_relics.size()):
		if not _relics_taken[i]:
			_add_relic_reward_button(_relics[i], i)
	
	## 添加卡牌奖励（如果未领取）
	if not _cards_taken and (_card_reward_offered or not _card_reward_ids.is_empty()):
		_add_card_reward_button()
	
	if not _upgrade_taken and _upgrade_offered and _deck_has_upgradeable_card():
		_add_card_upgrade_reward_button()
	elif _upgrade_offered and not _deck_has_upgradeable_card():
		_auto_skip_card_upgrade_reward_if_deck_fully_upgraded()


## 确保选牌界面关闭，回到奖励栏主界面
## 重进时不需要恢复选牌界面，只需确保奖励栏按钮显示正确
func restore_card_picker_if_pending() -> void:
	var run := get_tree().get_first_node_in_group("run") as Run
	if run != null:
		run.dismiss_reward_flow_overlays()
	_close_any_sub_overlays()


## 关闭所有子覆盖层
func _close_any_sub_overlays() -> void:
	## 查找并关闭选牌层（通常挂在 root 上）
	for child: Node in get_tree().root.get_children():
		if child is CardPickOverlay:
			child.queue_free()
	var run := get_tree().get_first_node_in_group("run") as Run
	if run != null:
		run.dismiss_reward_flow_overlays()


## 用户点击卡牌奖励按钮时显示选牌界面
func _show_card_rewards() -> void:
	if not run_stats or not character_stats or _cards_taken:
		return
	var card_reward_array := _roll_or_restore_card_rewards()
	if card_reward_array.is_empty():
		return
	_open_card_rewards_overlay(card_reward_array)


## 添加金币奖励按钮
func _add_gold_reward_button(amount: int) -> void:
	var gold_reward := REWARD_BUTTON.instantiate() as RewardButton
	gold_reward.reward_icon = GOLD_ICON
	gold_reward.reward_text = GOLD_TEXT % amount
	gold_reward.pressed.connect(_on_gold_reward_taken.bind(amount))
	rewards.add_child.call_deferred(gold_reward)


## 添加卡牌奖励按钮
func _add_card_reward_button() -> void:
	var card_reward := REWARD_BUTTON.instantiate() as RewardButton
	card_reward.remove_on_press = false
	card_reward.reward_icon = CARD_ICON
	card_reward.reward_text = CARD_TEXT
	card_reward.pressed.connect(_show_card_rewards)
	rewards.add_child.call_deferred(card_reward)


## 添加遗物奖励按钮
func _add_relic_reward_button(relic: Relic, index: int) -> void:
	if not relic:
		return
	var relic_reward := REWARD_BUTTON.instantiate() as RewardButton
	relic_reward.reward_icon = relic.icon
	relic_reward.reward_text = relic.relic_name
	relic_reward.hover_relic = relic
	relic_reward.pressed.connect(_on_relic_reward_taken.bind(relic, index))
	rewards.add_child.call_deferred(relic_reward)


## 公共方法：添加金币奖励
func add_gold_reward(amount: int) -> void:
	_gold_amount = amount
	_gold_taken = false
	if not _is_reload:
		_add_gold_reward_button(amount)


func _deck_has_upgradeable_card() -> bool:
	if character_stats == null or character_stats.deck == null:
		return false
	for c: Card in character_stats.deck.cards:
		if c != null and c.has_any_upgradeable_track():
			return true
	return false


## 公共方法：添加「升级一张牌」奖励（精英战）
func add_card_upgrade_reward() -> void:
	if not _deck_has_upgradeable_card():
		return
	_upgrade_offered = true
	if not _is_reload:
		_add_card_upgrade_reward_button()


func _add_card_upgrade_reward_button() -> void:
	var upgrade_reward := REWARD_BUTTON.instantiate() as RewardButton
	upgrade_reward.remove_on_press = false
	upgrade_reward.reward_icon = UPGRADE_ICON
	upgrade_reward.reward_text = UPGRADE_TEXT
	upgrade_reward.pressed.connect(_on_card_upgrade_reward_pressed)
	rewards.add_child.call_deferred(upgrade_reward)


func _on_card_upgrade_reward_pressed() -> void:
	if _upgrade_taken or _upgrade_flow_active or not character_stats:
		return
	_show_card_upgrade_flow()


func _auto_skip_card_upgrade_reward_if_deck_fully_upgraded() -> void:
	if _upgrade_taken or not _upgrade_offered:
		return
	_resolve_upgrade_reward_skipped()


func _bind_deck_picker_nav_wait(overlay: DeckPickerOverlay, captured: Dictionary) -> void:
	if not is_instance_valid(overlay):
		return
	var on_confirm := func(indices: Array) -> void:
		captured["kind"] = "confirm"
		captured["indices"] = indices
	overlay.pick_confirmed.connect(on_confirm, CONNECT_ONE_SHOT)
	overlay.pick_back.connect(func() -> void: captured["kind"] = "back", CONNECT_ONE_SHOT)


func _wait_deck_picker_nav(overlay: DeckPickerOverlay, captured: Dictionary) -> void:
	while (
		String(captured.get("kind", "")) == ""
		and is_instance_valid(overlay)
		and overlay.is_inside_tree()
	):
		await get_tree().process_frame


func _close_upgrade_reward_overlays(run: Run, overlay: Node) -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	if run != null:
		run.dismiss_reward_flow_overlays()


func _show_card_upgrade_flow() -> void:
	if not character_stats or character_stats.deck == null:
		return
	if not _deck_has_upgradeable_card():
		_auto_skip_card_upgrade_reward_if_deck_fully_upgraded()
		return
	var run := get_tree().get_first_node_in_group("run") as Run
	if run == null:
		return
	_upgrade_flow_active = true
	var overlay := DeckPickerOverlay.open_on_tree(get_tree())
	overlay.setup(
		character_stats.deck,
		1,
		Callable(),
		"点击卡牌进入升级。",
		PackedStringArray(),
		Callable(),
		Callable(self, "_deck_has_upgradeable_card_for_pick"),
		true,
		true,
		true
	)
	var captured: Dictionary = {"kind": "", "indices": []}
	while true:
		captured["kind"] = ""
		captured["indices"] = []
		if not is_instance_valid(overlay) or not overlay.is_inside_tree():
			break
		_bind_deck_picker_nav_wait(overlay, captured)
		await _wait_deck_picker_nav(overlay, captured)
		var kind: String = String(captured.get("kind", ""))
		if kind == "back":
			_upgrade_flow_active = false
			_close_upgrade_reward_overlays(run, overlay)
			return
		if kind != "confirm":
			_upgrade_flow_active = false
			_close_upgrade_reward_overlays(run, overlay)
			return
		var indices: Array = captured.get("indices", [])
		if indices.is_empty():
			_upgrade_flow_active = false
			_close_upgrade_reward_overlays(run, overlay)
			return
		var idx := int(indices[0])
		## 点选即确认（defer_free）：选牌层保持打开，升级层叠在上
		var flow := CardUpgradeFlow.open_on_tree(get_tree())
		flow.begin(character_stats.deck, idx)
		var result: int = await flow.finished
		if result == CardUpgradeFlow.Result.BACK_TO_PICK:
			if is_instance_valid(overlay):
				overlay.clear_selection()
			continue
		_close_upgrade_reward_overlays(run, overlay)
		if result == CardUpgradeFlow.Result.CANCELLED:
			_upgrade_flow_active = false
			return
		if result == CardUpgradeFlow.Result.UPGRADED:
			_resolve_card_upgrade_reward(idx)
			_upgrade_flow_active = false
			return
	_upgrade_flow_active = false


func _deck_has_upgradeable_card_for_pick(c: Card) -> bool:
	return c != null and c.has_any_upgradeable_track()


func _resolve_upgrade_reward_skipped() -> void:
	if _upgrade_taken:
		return
	_upgrade_taken = true
	var run := get_tree().get_first_node_in_group("run") as Run
	if run != null:
		run.take_battle_reward_upgrade()
	_rebuild_reward_ui()


func _resolve_card_upgrade_reward(deck_index: int) -> void:
	if _upgrade_taken:
		return
	_upgrade_taken = true
	var run := get_tree().get_first_node_in_group("run") as Run
	if run != null:
		run.take_battle_reward_upgrade()
		if (
			character_stats != null
			and character_stats.deck != null
			and deck_index >= 0
			and deck_index < character_stats.deck.cards.size()
		):
			await run.await_deck_gain_card_visual(
				character_stats.deck.cards[deck_index], Vector2.ZERO
			)
	_rebuild_reward_ui()


## 公共方法：添加卡牌奖励
func add_card_reward() -> void:
	if not _is_reload:
		_card_reward_offered = true
		_add_card_reward_button()


## 公共方法：添加必定Rare的卡牌奖励（层BOSS奖励专用）
func add_rare_card_reward() -> void:
	if _is_reload:
		return
	
	## 生成必定Rare的卡牌列表（3选1）
	var available_cards: Array[Card] = character_stats.draftable_cards.duplicate_cards()
	var rare_cards: Array[Card] = []
	for c: Card in available_cards:
		if c.rarity == Card.Rarity.RARE:
			rare_cards.append(c)
	
	## 如果没有Rare卡牌，回退到普通卡牌奖励
	if rare_cards.is_empty():
		add_card_reward()
		return
	
	## 随机选择3张Rare卡牌（或全部如果不足3张）
	var pick_count := mini(3, rare_cards.size())
	var selected_cards: Array[Card] = []
	while selected_cards.size() < pick_count and rare_cards.size() > 0:
		var idx := RNG.instance.randi() % rare_cards.size()
		selected_cards.append(rare_cards[idx])
		rare_cards.remove_at(idx)
	
	## 保存卡牌奖励ID（使用Rare卡牌）
	var run := get_tree().get_first_node_in_group("run") as Run
	if run != null:
		var ids := PackedStringArray()
		for c: Card in selected_cards:
			ids.append(c.id)
		_card_reward_ids = ids
		_card_reward_offered = true
		run.persist_battle_reward_cards_pending(ids)
	
	## 添加稀有卡牌奖励按钮（使用标准描述）
	var card_reward := REWARD_BUTTON.instantiate() as RewardButton
	card_reward.remove_on_press = false
	card_reward.reward_icon = CARD_ICON
	card_reward.reward_text = CARD_TEXT  ## 使用标准常量"添加新卡牌"
	card_reward.pressed.connect(_show_card_rewards)
	rewards.add_child.call_deferred(card_reward)


## 公共方法：添加遗物奖励
func add_relic_reward(relic: Relic) -> void:
	if not relic:
		return
	var index := _relics.size()
	_relics.append(relic)
	_relics_taken.append(false)
	if not _is_reload:
		_add_relic_reward_button(relic, index)


## 生成或恢复卡牌奖励列表
func _roll_or_restore_card_rewards() -> Array[Card]:
	var run := get_tree().get_first_node_in_group("run") as Run
	
	## 如果已经设置了卡牌奖励ID（如add_rare_card_reward设置的Rare卡），直接使用
	if not _card_reward_ids.is_empty() and run != null:
		return run.get_pending_card_templates()
	
	## 获取当前层数
	var floors_climbed := 0
	if run != null and run.save_data != null:
		floors_climbed = run.save_data.floors_climbed
	
	## 判断是否Boss奖励（使用固定权重）
	var is_boss_reward := (run != null and run.map != null and run.map.last_room != null 
		and run.map.last_room.type == Room.Type.BOSS)
	
	## 获取动态或固定稀有度权重
	var weights: Dictionary
	if is_boss_reward:
		## Boss奖励使用固定权重
		weights = {
			"common": RunStats.BASE_COMMON_WEIGHT,
			"uncommon": RunStats.BASE_UNCOMMON_WEIGHT,
			"rare": RunStats.BASE_RARE_WEIGHT
		}
	else:
		## 普通奖励使用动态权重
		weights = run_stats.get_dynamic_weights(floors_climbed)
		
		## 应用稀有度连锁惩罚
		if run != null and run.save_data != null:
			weights = run_stats.apply_rarity_streak_penalty(
				weights,
				run.save_data.last_card_reward_rarity,
				run.save_data.rarity_streak_count
			)
	
	## 生成普通随机卡牌奖励
	var available_cards: Array[Card] = character_stats.draftable_cards.duplicate_cards()
	var pick_count := mini(run_stats.card_rewards, available_cards.size())
	var card_reward_array := RNG.pick_weighted_distinct_cards(
		available_cards,
		pick_count,
		weights.common,
		weights.uncommon,
		weights.rare
	)
	
	## 记录本次抽到的稀有度（用于连锁惩罚和回升）
	if run != null and run.save_data != null and not card_reward_array.is_empty():
		var first_card_rarity := card_reward_array[0].rarity
		var base_weights := run_stats.get_dynamic_weights(floors_climbed)
		
		if first_card_rarity == run.save_data.last_card_reward_rarity:
			## 连续同稀有度，加重惩罚
			run.save_data.rarity_streak_count += 1
		else:
			## 抽到不同稀有度，逐步恢复之前的惩罚
			if run.save_data.rarity_streak_count > 0 and run.save_data.last_card_reward_rarity >= 0:
				## 使用回升机制恢复之前被惩罚的稀有度权重
				var recovered_weights := run_stats.recover_rarity_weights(
					weights,
					base_weights,
					run.save_data.last_card_reward_rarity
				)
				## 更新权重用于下次计算
				weights = recovered_weights
				## 降低惩罚计数（逐步回升）
				run.save_data.rarity_streak_count = maxi(run.save_data.rarity_streak_count - 1, 0)
				
				## 如果惩罚已完全恢复，重置稀有度记录
				if run.save_data.rarity_streak_count == 0:
					run.save_data.last_card_reward_rarity = first_card_rarity
					run.save_data.rarity_streak_count = 1
			else:
				## 没有之前的惩罚，直接记录新的稀有度
				run.save_data.last_card_reward_rarity = first_card_rarity
				run.save_data.rarity_streak_count = 1
	
	## 获取动态升级概率
	var upgrade_once_chance := run_stats.get_upgrade_chance_tier1(floors_climbed)
	var upgrade_twice_chance := run_stats.get_upgrade_chance_tier2(floors_climbed)
	
	## 为每张卡牌应用随机升级概率
	for card: Card in card_reward_array:
		if not card.has_any_upgradeable_track():
			continue
		var roll := RNG.instance.randf()
		if roll < upgrade_twice_chance:
			_apply_random_upgrades(card, 2)
		elif roll < upgrade_twice_chance + upgrade_once_chance:
			_apply_random_upgrades(card, 1)
	
	if run != null:
		var ids := PackedStringArray()
		for c: Card in card_reward_array:
			ids.append(c.id)
		_card_reward_ids = ids
		_card_reward_offered = true
		run.persist_battle_reward_cards_pending(ids)
	return card_reward_array


## 打开卡牌奖励覆盖层
func _open_card_rewards_overlay(card_reward_array: Array[Card]) -> void:
	var overlay := CardPickOverlay.present(card_reward_array)
	overlay.card_pick_selected.connect(_on_card_reward_selected, CONNECT_ONE_SHOT)
	overlay.card_pick_skipped.connect(_on_card_reward_skipped, CONNECT_ONE_SHOT)
	overlay.card_pick_back.connect(_on_card_reward_back, CONNECT_ONE_SHOT)


## 返回：未处理卡牌奖励，保留「添加新卡牌」入口与已 roll 的候选
func _on_card_reward_back() -> void:
	pass


## 跳过：放弃本次卡牌奖励，视为已处理
func _on_card_reward_skipped() -> void:
	_resolve_card_reward_without_pick()


func _on_card_reward_selected(picked_menu: Variant, from_global: Vector2) -> void:
	if picked_menu == null or not (picked_menu is CardMenuUI):
		return
	_on_card_reward_taken(picked_menu, from_global)


## 跳过或选牌后：标记已领取并刷新奖励栏（移除选牌按钮）
func _resolve_card_reward_without_pick() -> void:
	if _cards_taken:
		return
	_cards_taken = true
	var run := get_tree().get_first_node_in_group("run") as Run
	if run != null:
		run.take_battle_reward_cards()
	_rebuild_reward_ui()


## 金币奖励被领取
func _on_gold_reward_taken(amount: int) -> void:
	if not run_stats:
		return
	
	run_stats.gold += amount
	_gold_taken = true
	
	## 更新保存状态
	var run := get_tree().get_first_node_in_group("run") as Run
	if run != null:
		run.take_battle_reward_gold()


## 卡牌奖励被领取
func _on_card_reward_taken(picked_menu: Variant, from_global: Vector2) -> void:
	if not character_stats or picked_menu == null or not (picked_menu is CardMenuUI):
		return
	
	var run := get_tree().get_first_node_in_group("run") as Run
	
	var menu := picked_menu as CardMenuUI
	var card := menu.card
	if not card:
		menu.queue_free()
		return
	
	_cards_taken = true
	
	if run != null:
		run.take_battle_reward_cards()
		run.play_deck_gain_card_visual_with_pick(menu, from_global)
	
	character_stats.deck.add_card(card)
	_rebuild_reward_ui()


## 遗物奖励被领取
func _on_relic_reward_taken(relic: Relic, index: int) -> void:
	if not relic or not relic_handler:
		return
	
	var run := get_tree().get_first_node_in_group("run") as Run
	if run == null:
		return
	
	## 1. 先保存领取前的快照状态
	_save_battle_reward_pending_snapshot(run, index)
	
	## 2. 标记遗物为"领取中"（但未确认）
	if index >= 0 and index < _relics_taken.size():
		_relics_taken[index] = true  ## 本地标记，防止重复点击
	_rebuild_reward_ui()  ## 立即刷新UI，隐藏该遗物按钮
	
	## 3. 执行遗物效果（可能涉及异步UI流程，如无上宝石的选牌升级）
	await relic_handler.add_relic_async(relic)
	
	## 玩家在效果 UI 中取消或保存退出：遗物未真正入栏，恢复该格奖励按钮
	if not relic_handler.has_relic(relic.id):
		if index >= 0 and index < _relics_taken.size():
			_relics_taken[index] = false
		_rebuild_reward_ui()
		run.save_data.clear_battle_reward_pending_staging()
		run._save_run(false)
		return
	
	## 4. 效果完成，确认领取（保留 entry 快照直至离开奖励栏/保存退出回滚）
	run.take_battle_reward_relic(index)
	run.save_data.clear_battle_reward_pending_staging()
	run._save_run(false)


## 保存领取遗物前的快照状态
func _save_battle_reward_pending_snapshot(run: Run, relic_index: int) -> void:
	if run == null or run.save_data == null:
		return
	
	var sd := run.save_data
	sd.battle_reward_pending_kind = SaveGame.BATTLE_REWARD_PENDING_RELIC
	sd.battle_reward_pending_relic_index = relic_index
	
	## 保存当前状态
	if character_stats != null:
		sd.battle_reward_pending_pre_health = character_stats.health
	if run_stats != null:
		sd.battle_reward_pending_pre_gold = run_stats.gold
	
	## 保存卡组
	sd.battle_reward_pending_pre_deck_cards.clear()
	if character_stats != null and character_stats.deck != null:
		for card in character_stats.deck.cards:
			sd.battle_reward_pending_pre_deck_cards.append(card.duplicate(true) as Card)
	
	## 保存遗物ID列表
	sd.battle_reward_pending_pre_relic_ids.clear()
	var current_relics := relic_handler.get_all_relics()
	for r: Relic in current_relics:
		if is_instance_valid(r) and r.id != "":
			sd.battle_reward_pending_pre_relic_ids.append(r.id)
	
	## 保存RNG状态
	sd.battle_reward_pending_pre_rng_seed = RNG.instance.seed
	sd.battle_reward_pending_pre_rng_state = RNG.instance.state
	
	print("[BattleReward] 保存领取前快照: health=%d, gold=%d, relics=%d, deck_cards=%d" % [
		sd.battle_reward_pending_pre_health,
		sd.battle_reward_pending_pre_gold,
		sd.battle_reward_pending_pre_relic_ids.size(),
		sd.battle_reward_pending_pre_deck_cards.size()
	])
	run._save_run(false)


## 返回按钮被按下
func _on_back_button_pressed() -> void: 
	Events.battle_reward_exited.emit()


## 为卡牌应用随机升级（随机选择可升级轨道）
func _apply_random_upgrades(card: Card, count: int) -> void:
	if not card or not card.has_any_upgradeable_track():
		return
	
	for i in range(count):
		# 获取当前仍可升级的轨道
		var upgradeable_tracks: Array[String] = []
		for track_id in card.get_upgrade_track_ids():
			if not card.is_upgrade_track_maxed(track_id):
				upgradeable_tracks.append(track_id)
		
		# 没有可升级轨道时停止
		if upgradeable_tracks.is_empty():
			break
		
		# 随机选择一个轨道进行升级
		var chosen_track := upgradeable_tracks[RNG.instance.randi() % upgradeable_tracks.size()]
		card.increment_upgrade_track(chosen_track)
