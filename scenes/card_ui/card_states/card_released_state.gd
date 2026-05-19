extends CardState


func enter() -> void:
	if not card_ui.char_stats.can_play_card(card_ui.card, card_ui.get_effective_mana_cost()):
		return

	var single_targeted := card_ui.card.is_single_targeted()
	
	# 单目标卡牌必须有目标才能释放
	if single_targeted and card_ui.targets.is_empty():
		return
	
	# 非单目标卡牌（全体攻击等）：如果没有目标，自动获取所有敌人
	if not single_targeted and card_ui.targets.is_empty():
		var tree := card_ui.get_tree()
		if tree != null:
			var all_enemies := tree.get_nodes_in_group("enemies")
			for enemy in all_enemies:
				if is_instance_valid(enemy):
					card_ui.targets.append(enemy)
		# 如果仍然没有目标，则无法释放
		if card_ui.targets.is_empty():
			return

	var first_target_is_enemy := card_ui.targets[0] is Enemy
	
	if single_targeted and not first_target_is_enemy:
		return

	await card_ui.play()


func post_enter() -> void:
	transition_requested.emit(self, CardState.State.BASE)
