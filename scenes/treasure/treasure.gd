class_name Treasure
extends Control

const TREASURE_OPEN_SFX := preload("res://art/treasure.ogg")

@export var treasure_relic_pool: Array[Relic]
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
		2:
			bg_rect.texture = preload("res://art/background.png")
		3:
			bg_rect.texture = preload("res://art/act3_background.png")
		_:
			bg_rect.texture = preload("res://art/background.png")


func generate_relic() -> void:
	var available_relics := treasure_relic_pool.filter(
		func(relic: Relic):
			var can_appear := relic.can_appear_as_reward(char_stats)
			var already_had_it := relic_handler.has_relic(relic.id)
			return can_appear and not already_had_it
	)
	found_relic = RNG.array_pick_random(available_relics)


# Called from the AnimationPlayer, at the
# end of the 'open' animation.
func _on_treasure_opened() -> void:
	Events.treasure_room_exited.emit(found_relic)


func _on_treasure_chest_gui_input(event: InputEvent) -> void:
	if animation_player.current_animation == "open":
		return
	
	if event.is_action_pressed("left_mouse"):
		SFXPlayer.play(TREASURE_OPEN_SFX)
		animation_player.play("open")
