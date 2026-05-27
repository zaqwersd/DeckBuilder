extends Relic

func add_to_bar_before_persistent_pickup() -> bool:
	return true


## 拾起效果在异步流程中执行（打开当前界面上的奖励栏）
func apply_persistent_pickup_on_acquire(_run: Node) -> void:
	pass


func apply_persistent_pickup_on_acquire_async(run_node: Node) -> void:
	var run := run_node as Run
	if run == null:
		return
	await run.run_inline_reward_pack_flow()
