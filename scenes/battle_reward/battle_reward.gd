class_name BattleReward
extends Control

const CARD_REWARDS = preload("res://scenes/ui/card_rewards.tscn")
const REWARD_BUTTON = preload("res://scenes/ui/reward_button.tscn")
const GOLD_ICON := preload("res://art/gold.png")
const GOLD_TEXT := "%s 金币"
const CARD_ICON := preload("res://art/rarity.png")
const CARD_TEXT := "添加新卡牌"

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
var _card_reward_ids: PackedStringArray = PackedStringArray()
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
			bg_rect.texture = preload("res://art/background.png")
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
	run.persist_battle_reward_full_state(_gold_amount, relics_to_save)


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
	
	## 重置存档中的领取状态，确保下次保存也是未领取
	run.save_data.battle_reward_gold_taken = false
	run.save_data.battle_reward_cards_taken = false
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
	if not _cards_taken and not _card_reward_ids.is_empty():
		_add_card_reward_button()


## 确保选牌界面关闭，回到奖励栏主界面
## 重进时不需要恢复选牌界面，只需确保奖励栏按钮显示正确
func restore_card_picker_if_pending() -> void:
	## 关闭任何可能存在的子界面（如选牌界面）
	_close_any_sub_overlays()


## 关闭所有子覆盖层
func _close_any_sub_overlays() -> void:
	## 查找并关闭 CardRewards 子界面
	for child: Node in get_children():
		if child is CardRewards:
			child.queue_free()


## 用户点击卡牌奖励按钮时显示选牌界面
func _show_card_rewards() -> void:
	if not run_stats or not character_stats:
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


## 公共方法：添加卡牌奖励
func add_card_reward() -> void:
	if not _is_reload:
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
		run.persist_battle_reward_cards_pending(ids)
	
	## 添加稀有卡牌奖励按钮（使用标准描述）
	var card_reward := REWARD_BUTTON.instantiate() as RewardButton
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
	
	## 生成普通随机卡牌奖励
	var available_cards: Array[Card] = character_stats.draftable_cards.duplicate_cards()
	var pick_count := mini(run_stats.card_rewards, available_cards.size())
	var card_reward_array := RNG.pick_weighted_distinct_cards(
		available_cards,
		pick_count,
		run_stats.common_weight,
		run_stats.uncommon_weight,
		run_stats.rare_weight
	)
	if run != null:
		var ids := PackedStringArray()
		for c: Card in card_reward_array:
			ids.append(c.id)
		_card_reward_ids = ids
		run.persist_battle_reward_cards_pending(ids)
	return card_reward_array


## 打开卡牌奖励覆盖层
func _open_card_rewards_overlay(card_reward_array: Array[Card]) -> void:
	var card_rewards := CARD_REWARDS.instantiate() as CardRewards
	card_rewards.card_reward_selected.connect(_on_card_reward_taken, CONNECT_ONE_SHOT)
	card_rewards.rewards = card_reward_array
	get_tree().root.add_child(card_rewards)
	card_rewards.show()


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


## 遗物奖励被领取
func _on_relic_reward_taken(relic: Relic, index: int) -> void:
	if not relic or not relic_handler:
		return
	
	relic_handler.add_relic(relic)
	
	if index >= 0 and index < _relics_taken.size():
		_relics_taken[index] = true
	
	## 更新保存状态
	var run := get_tree().get_first_node_in_group("run") as Run
	if run != null:
		run.take_battle_reward_relic(index)


## 返回按钮被按下
func _on_back_button_pressed() -> void: 
	Events.battle_reward_exited.emit()
