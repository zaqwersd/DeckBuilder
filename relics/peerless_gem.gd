extends Relic


## 筛选可升级的卡牌
func _filter_upgradeable(card: Card) -> bool:
	return card.has_any_upgradeable_track()


## 遗物拾起时触发：选择一张卡牌并将其所有词条升至满级
func apply_persistent_pickup_on_acquire(_run: Node) -> void:
	var run := _run as Run
	if run == null or run.character == null:
		return
	
	## 检查牌组中是否有可升级的卡牌
	var has_upgradeable := false
	for card in run.character.deck.cards:
		if card.has_any_upgradeable_track():
			has_upgradeable = true
			break
	
	if not has_upgradeable:
		## 没有可升级的卡牌，直接返回
		return
	
	## 打开牌组选择界面
	var overlay := DeckPickerOverlay.open_on_tree(run.get_tree())
	overlay.setup(
		run.character.deck,
		1,  ## 只选1张
		Callable(),  ## 无需额外验证
		"选择一张卡牌将其所有词条升至满级",
		PackedStringArray(),  ## 不限制特定卡牌ID
		Callable(),  ## 使用默认确认条件（选满1张）
		Callable(self, "_filter_upgradeable"),  ## 只显示可升级的卡牌
		true,  ## 单选时自动确认
		true   ## 延迟释放，等待升级流程结束
	)
	
	## 循环处理选牌和升级，直到玩家确认升级或彻底取消
	while true:
		var indices: Array = await overlay.pick_confirmed
		if indices.is_empty():
			## 玩家在选牌界面取消，彻底结束
			overlay.queue_free()
			return
		
		var idx: int = indices[0]
		
		## 打开升级流程，直接显示满级预览
		var flow := CardUpgradeFlow.open_on_tree(run.get_tree())
		flow.begin_max_out(run.character.deck, idx)
		
		var result: int = await flow.finished
		
		if result == CardUpgradeFlow.Result.UPGRADED:
			## 升级成功，播放卡牌飞入牌库动画
			if run:
				await run.await_deck_gain_card_visual(run.character.deck.cards[idx], Vector2.ZERO)
			overlay.queue_free()
			return
		elif result == CardUpgradeFlow.Result.CANCELLED:
			## 彻底取消，结束流程
			overlay.queue_free()
			return
		## else BACK_TO_PICK: 继续循环，回到选牌界面
