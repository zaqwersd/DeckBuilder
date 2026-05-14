extends Card

const CARD_SELECTOR_SCREEN := preload("res://scenes/ui/card_selector_screen.tscn")

var base_block := 7
var upgraded_block := 10
var exhaust_amount := 1

var _selector_screen: CardSelectorScreen = null


func get_default_tooltip() -> String:
	var block_value := upgraded_block if get_total_upgrade_count() > 0 else base_block
	var random_keyword := "[color=%s]随机[/color]" % CardUpgradeUiColors.BB_NEGATIVE_REMOVABLE
	
	if get_total_upgrade_count() > 0:
		# 升级后：去掉"随机"
		return "[center]获得 %s 点格挡。\n消耗 1 张手牌。[/center]" % block_value
	else:
		# 未升级：显示"随机"
		return "[center]获得 %s 点格挡。\n%s消耗 1 张手牌。[/center]" % [block_value, random_keyword]


func get_updated_tooltip(
	_player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler, _combat_player: Node = null
) -> String:
	var block_value := upgraded_block if get_total_upgrade_count() > 0 else base_block
	var display_block := bbcode_for_modified_number(block_value, block_value)
	var random_keyword := "[color=%s]随机[/color]" % CardUpgradeUiColors.BB_NEGATIVE_REMOVABLE
	
	if get_total_upgrade_count() > 0:
		return "[center]获得 %s 点格挡。\n消耗 1 张手牌。[/center]" % display_block
	else:
		return "[center]获得 %s 点格挡。\n%s消耗 1 张手牌。[/center]" % [display_block, random_keyword]


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var is_upgraded := get_total_upgrade_count() > 0
	var block_value := upgraded_block if is_upgraded else base_block
	
	# 应用格挡效果
	var block_effect := BlockEffect.new()
	block_effect.amount = block_value
	block_effect.sound = sound
	block_effect.execute(targets)
	
	# 处理消耗手牌逻辑
	if is_upgraded:
		# 升级后：打开选牌界面
		await _show_card_selector()
	else:
		# 未升级：随机消耗
		var exhaust_random_effect := ExhaustRandomEffect.new()
		exhaust_random_effect.amount = exhaust_amount
		await exhaust_random_effect.execute(targets)


func _show_card_selector() -> void:
	# 获取手牌
	var hand := _get_hand()
	if hand == null or hand.get_child_count() == 0:
		return
	
	# 收集手牌中的卡牌
	var available_cards: Array[Card] = []
	for slot in hand.get_children():
		var card_ui := _get_card_ui_in_slot(slot)
		if card_ui != null and card_ui.card != null:
			available_cards.append(card_ui.card)
	
	if available_cards.is_empty():
		return
	
	# 创建或获取选牌界面
	if _selector_screen == null:
		_selector_screen = CARD_SELECTOR_SCREEN.instantiate()
		get_tree().root.add_child(_selector_screen)
		_selector_screen.selection_confirmed.connect(_on_cards_selected)
		_selector_screen.selection_cancelled.connect(_on_selection_cancelled)
	
	# 显示选牌界面
	_selector_screen.show_selector(available_cards, "选择要消耗的卡牌", 1)
	
	# 等待选择完成
	await _selector_screen.selection_confirmed
	await _selector_screen.selection_cancelled


func _on_cards_selected(selected_cards: Array[Card]) -> void:
	if selected_cards.is_empty():
		return
	
	# 消耗选中的卡牌
	var hand := _get_hand()
	if hand == null:
		return
	
	for card in selected_cards:
		Events.card_exhausted.emit(card)
		# 从手牌中移除
		for slot in hand.get_children():
			var card_ui := _get_card_ui_in_slot(slot)
			if card_ui != null and card_ui.card == card:
				card_ui.queue_free()
				break


func _on_selection_cancelled() -> void:
	# 用户取消选择，不做任何操作
	pass


func _get_hand() -> Node:
	# 从场景中查找手牌节点
	var tree := get_tree()
	if tree == null:
		return null
	
	# 尝试通过组查找
	var hands := tree.get_nodes_in_group("hand")
	if not hands.is_empty():
		return hands[0]
	
	# 尝试通过路径查找
	var battle := tree.get_first_node_in_group("battle")
	if battle != null:
		var hand = battle.get_node_or_null("BattleUI/Hand")
		if hand != null:
			return hand
	
	return null


func _get_card_ui_in_slot(slot: Node) -> Node:
	for child in slot.get_children():
		if child.is_in_group("card_ui") or child.has_method("play"):
			return child
	return null
