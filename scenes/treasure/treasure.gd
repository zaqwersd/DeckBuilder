class_name Treasure
extends Control

const TREASURE_OPEN_SFX := preload("res://art/treasure.ogg")

@export var relic_reward_pool: RelicRewardPool
@export var relic_handler: RelicHandler
@export var char_stats: CharacterStats

@onready var animation_player: AnimationPlayer = %AnimationPlayer
var found_relic: Relic


func populate_from_run(is_reload: bool) -> void:
	_setup_background()
	
	var run := get_tree().get_first_node_in_group("run") as Run
	if is_reload and run != null:
		var restored := run.get_pending_treasure_relic()
		if restored != null:
			found_relic = restored
			# 重置动画到初始状态（未打开）
			if animation_player:
				animation_player.play("RESET")
			return
	generate_relic()
	if run != null and found_relic != null:
		run.persist_treasure_pending(found_relic.id)


## 设置与当前层数匹配的背景图
func _setup_background() -> void:
	var bg_rect := $Background as TextureRect
	if bg_rect == null:
		return
	
	var run := get_tree().get_first_node_in_group("run") as Run
	if run == null:
		return
	
	## 根据当前层数设置对应背景图
	match run.current_act:
		1:
			bg_rect.texture = preload("res://art/act1_background.png")
			bg_rect.modulate = Color(1, 1, 1, 1)
		2:
			bg_rect.texture = preload("res://art/act2_background.png")
			bg_rect.modulate = Color(1, 1, 1, 1)
		3:
			bg_rect.texture = preload("res://art/act3_background.png")
			bg_rect.modulate = Color(0.86, 0.80, 0.72, 1)
		_:
			bg_rect.texture = preload("res://art/background.png")
			bg_rect.modulate = Color(1, 1, 1, 1)


func generate_relic() -> void:
	if not relic_reward_pool:
		return
	var act_number := 1
	var run_stats_ref: RunStats = null
	var run := get_tree().get_first_node_in_group("run") as Run
	if run != null:
		if run.save_data != null:
			act_number = run.save_data.act_number
		run_stats_ref = run.stats
	found_relic = relic_reward_pool.roll_reward(
		char_stats, relic_handler, act_number, run_stats_ref
	)


# Called from the AnimationPlayer, at the
# end of the 'open' animation.
func _on_treasure_opened() -> void:
	var run := get_tree().get_first_node_in_group("run") as Run
	if run != null and RunBgm.is_row8_tense_treasure_room(run):
		RunBgm.on_row8_tense_treasure_opened(run)
	Events.treasure_room_exited.emit(found_relic)


func _on_treasure_chest_gui_input(event: InputEvent) -> void:
	if animation_player.current_animation == "open":
		return
	
	if event.is_action_pressed("left_mouse"):
		SFXPlayer.play(TREASURE_OPEN_SFX)
		animation_player.play("open")
