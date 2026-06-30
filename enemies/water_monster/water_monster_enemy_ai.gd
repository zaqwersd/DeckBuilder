extends EnemyActionPicker

## 0:三 debuff；1:10 甲；2:打 20；3:+5 力 → 回到 1 循环
var _phase: int = 0


func _ready() -> void:
	super._ready()


func notify_picker_action_finished() -> void:
	if not is_instance_valid(enemy):
		return
	if _phase == 3:
		_phase = 1
	elif _phase < 3:
		_phase += 1


func get_action() -> EnemyAction:
	match _phase:
		0:
			return $TripleDebuff as EnemyAction
		1:
			return $Block10 as EnemyAction
		2:
			return $Strike20 as EnemyAction
		3:
			return $Strength5 as EnemyAction
	return $TripleDebuff as EnemyAction


func get_first_conditional_action() -> EnemyAction:
	return null
