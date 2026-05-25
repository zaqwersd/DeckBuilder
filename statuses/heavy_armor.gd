class_name HeavyArmorStatus
extends Status

const THRESHOLD_RETALIATION_DAMAGE := 15
const THRESHOLD_STEP := 10
const INITIAL_THRESHOLD := 10

var threshold_n: int = INITIAL_THRESHOLD
var accumulated_m: int = 0
var stun_next_enemy_turn: bool = false


func get_tooltip() -> String:
	return (
		"当前最多失去%s点生命值（已失去%s）。当达到阈值时，眩晕该敌人，对玩家造成%d点伤害并将阈值提升%d。"
		% [
			format_counter_for_tooltip(threshold_n),
			format_counter_for_tooltip(accumulated_m),
			THRESHOLD_RETALIATION_DAMAGE,
			THRESHOLD_STEP,
		]
	)


## 将本次伤害请求限制为：扣除格挡后实际掉血不超过 (n - m)。
func clamp_incoming_damage(requested: int, current_block: int) -> int:
	var headroom := maxi(0, threshold_n - accumulated_m)
	if headroom <= 0:
		return mini(requested, current_block)
	if requested <= current_block:
		return requested
	return mini(requested, current_block + headroom)


## 实际失去的生命值（已扣格挡）计入 m。
func register_damage_taken(actual_hp_lost: int, host: Enemy) -> void:
	if actual_hp_lost <= 0:
		return
	accumulated_m += actual_hp_lost
	status_changed.emit()
	if accumulated_m >= threshold_n:
		_trigger_threshold(host)


func _trigger_threshold(host: Enemy) -> void:
	## 破甲判定在 take_damage 之后：若本次伤害已击杀 Boss，不再反伤/眩晕玩家。
	var boss_already_dead := (
		is_instance_valid(host)
		and is_instance_valid(host.stats)
		and host.stats.health <= 0
	)
	if not boss_already_dead:
		_deal_retaliation_damage_to_player()
	threshold_n += THRESHOLD_STEP
	accumulated_m = 0
	if not boss_already_dead:
		stun_next_enemy_turn = true
		status_changed.emit()
		if is_instance_valid(host):
			host.current_action = null
			host.update_action()
	else:
		status_changed.emit()


func _deal_retaliation_damage_to_player() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var player := tree.get_first_node_in_group("battle_player") as Player
	if player == null:
		return
	var dmg := DamageEffect.new()
	dmg.amount = THRESHOLD_RETALIATION_DAMAGE
	dmg.execute([player])


static func get_on_enemy(enemy: Enemy) -> HeavyArmorStatus:
	if enemy == null or enemy.status_handler == null:
		return null
	return enemy.status_handler.get_status_by_id("heavy_armor") as HeavyArmorStatus
