class_name IgneousExplodeAction
extends EnemyAction

@export var explosion_damage := 30
@export var charge_duration := 0.58
@export var peak_modulate := Color(2.35, 1.55, 1.12, 1.0)
@export var peak_scale_mul := 1.62


func perform_action() -> void:
	if not enemy or not target:
		return
	var player := target as Player
	if not player:
		return
	var picker := enemy.enemy_action_picker
	if picker is IgneousBursterAI:
		(picker as IgneousBursterAI).stop_explode_pulse()
	var spr := enemy.sprite_2d
	if spr == null:
		return
	var base_scale := spr.scale
	var modified := player.modifier_handler.get_modified_value(explosion_damage, Modifier.Type.DMG_TAKEN)
	var final_dmg := enemy.modifier_handler.get_modified_value(modified, Modifier.Type.DMG_DEALT)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(spr, "scale", base_scale * peak_scale_mul, charge_duration)
	tw.tween_property(spr, "modulate", peak_modulate, charge_duration)
	await tw.finished
	
	# 造成伤害
	if is_instance_valid(player):
		player.take_damage_final(final_dmg, false)
		SFXPlayer.play(sound)
	
	# 等待一帧确保伤害生效，然后检查玩家是否死亡
	await get_tree().process_frame
	
	# 如果玩家死亡，发送死亡事件并直接返回（不自爆，战斗已结束）
	if is_instance_valid(player) and player.stats.health <= 0:
		Events.player_died.emit()
		return
	
	# 玩家没死，继续自爆流程
	Events.enemy_action_completed.emit(enemy)
	if is_instance_valid(enemy):
		Events.enemy_died.emit(enemy)
		enemy.queue_free()


func update_intent_text() -> void:
	var player := target as Player
	if not player or not enemy or not intent:
		return
	var modified := player.modifier_handler.get_modified_value(explosion_damage, Modifier.Type.DMG_TAKEN)
	var per_hit := enemy.modifier_handler.get_modified_value(modified, Modifier.Type.DMG_DEALT)
	intent.set_attack_segments_display(per_hit, 1)
