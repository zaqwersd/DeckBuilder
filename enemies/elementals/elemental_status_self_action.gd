extends EnemyAction

@export var status: Status
@export var amount := 1


func update_planned_intents() -> void:
	if intent == null:
		return
	intent.display_number = Intent.NUMBER_HIDDEN
	var n := status.get_display_name() if status != null else "状态"
	intent.current_text = "+%d %s" % [amount, n]


func perform_action() -> void:
	if enemy == null or status == null:
		return
	var st := status.duplicate(true) as Status
	if st.stack_type == Status.StackType.INTENSITY:
		st.stacks = amount
	elif st.stack_type == Status.StackType.DURATION:
		st.duration = amount
	var effect := StatusEffect.new()
	effect.status = st
	effect.execute([enemy])
	await get_tree().create_timer(0.25).timeout
	Events.enemy_action_completed.emit(enemy)