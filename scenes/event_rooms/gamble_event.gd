extends EventRoom

@onready var fifty_button: EventRoomButton = %FiftyButton
@onready var thirty_button: EventRoomButton = %ThirtyButton
@onready var skip_button: EventRoomButton = %SkipButton


func setup() -> void:
	_bind_event_buttons()
	var low_gold := run_stats != null and run_stats.gold < 50
	if _is_run_reload:
		# 读档重进：恢复可点状态，并沿用与首次进入相同的显隐规则
		fifty_button.disabled = low_gold
		thirty_button.disabled = low_gold
		skip_button.visible = low_gold
	else:
		skip_button.visible = low_gold
		fifty_button.disabled = low_gold
		thirty_button.disabled = low_gold


func _bind_event_buttons() -> void:
	if not is_instance_valid(fifty_button) or not is_instance_valid(thirty_button):
		return
	fifty_button.event_button_callback = bet_50
	thirty_button.event_button_callback = bet_30


func bet_30() -> void:
	thirty_button.disabled = true
	run_stats.gold -= 50
	
	if RNG.instance.randf() < 0.3:
		run_stats.gold += 200


func bet_50() -> void:
	fifty_button.disabled = true
	run_stats.gold -= 50
	
	if RNG.instance.randf() < 0.5:
		run_stats.gold += 100
