class_name ExhaustRandomEffect
extends Effect

var amount := 1


func execute(targets: Array[Node]) -> void:
	if targets.is_empty():
		return
		
	var player_handler := targets[0].get_tree().get_first_node_in_group("player_handler") as PlayerHandler
	
	if not player_handler:
		return
	
	# 收集所有有效的手牌槽位（排除正在动画中的透明卡牌）
	var valid_slots: Array[Node] = []
	for slot in player_handler.hand.get_children():
		if not is_instance_valid(slot):
			continue
		var cui := player_handler.hand.get_card_ui_in_slot(slot as Control)
		# 排除正在动画中（透明）或无效的卡牌
		if cui and cui.card and cui.modulate.a > 0.01:
			valid_slots.append(slot)
	
	# 如果没有有效手牌，直接返回
	if valid_slots.is_empty():
		return
	
	RNG.array_shuffle(valid_slots)
	var chosen_slots := valid_slots.slice(0, amount)
	var ch := player_handler.character

	for slot in chosen_slots:
		if not is_instance_valid(slot):
			continue
		var cui := player_handler.hand.get_card_ui_in_slot(slot as Control)
		if cui and cui.card and ch and ch.exhaust:
			ch.exhaust.add_card(cui.card)
			# 播放手牌消耗动画（淡出效果）
			var bcf = player_handler.battle_card_fx
			if is_instance_valid(bcf) and bcf.has_method("animate_hand_card_exhaust"):
				await bcf.animate_hand_card_exhaust(player_handler.hand, cui)
			else:
				player_handler.hand.discard_card(cui)
