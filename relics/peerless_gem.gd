extends Relic

## 记录被升级的卡牌名，用于动态 tooltip
var upgraded_card_name: String = ""


## 筛选可升级的卡牌
func _filter_upgradeable(card: Card) -> bool:
	return card.has_any_upgradeable_track()


## 动态 tooltip：如果已升级过卡牌，显示升级记录
func get_tooltip() -> String:
	if not upgraded_card_name.is_empty():
		return "利用无上宝石的力量，你将[color=%s]%s[/color]升至了满级。" % [Card.COMBAT_MODIFIED_GREEN, upgraded_card_name]
	return tooltip


## 同步版本：无上宝石的效果需要UI交互，所以在同步版本中不执行任何操作
## 真正的效果在 apply_persistent_pickup_on_acquire_async 中执行
func apply_persistent_pickup_on_acquire(_run: Node) -> void:
	pass


## 异步版本：选择一张卡牌并将其所有词条升至满级
func apply_persistent_pickup_on_acquire_async(_run: Node) -> void:
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
			## 升级成功，记录被升级的卡牌名
			if run and run.character and idx < run.character.deck.cards.size():
				var upgraded_card: Card = run.character.deck.cards[idx]
				upgraded_card_name = upgraded_card.get_display_name()
			## 播放卡牌飞入牌库动画
			if run:
				await run.await_deck_gain_card_visual(run.character.deck.cards[idx], Vector2.ZERO)
			overlay.queue_free()
			return
		elif result == CardUpgradeFlow.Result.CANCELLED:
			## 彻底取消，结束流程
			overlay.queue_free()
			return
		## else BACK_TO_PICK: 清除选中状态，继续循环回到选牌界面
		overlay.clear_selection()
