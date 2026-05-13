extends EnemyActionPicker

## 0:弃牌堆塞3幽；1:打20+恶灵缠身2；2:打6+弃牌2幽；3:打3×3；4:+2力且恶灵缠身+1 → 回到2 循环 2–4
var _phase: int = 0


func _ready() -> void:
	super._ready()


func notify_picker_action_finished() -> void:
	if not is_instance_valid(enemy):
		return
	if _phase == 4:
		_phase = 2
	elif _phase < 4:
		_phase += 1


func get_action() -> EnemyAction:
	match _phase:
		0:
			return $InsertThreeGhosts as EnemyAction
		1:
			return $Strike15Haunted as EnemyAction
		2:
			return $Strike6Insert2Ghosts as EnemyAction
		3:
			return $TripleHit as EnemyAction
		4:
			return $BuffTwoHaunted1 as EnemyAction
	return $InsertThreeGhosts as EnemyAction


func get_first_conditional_action() -> EnemyAction:
	return null
