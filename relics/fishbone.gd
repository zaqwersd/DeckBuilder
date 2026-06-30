extends Relic

@export var bonus_damage := 1
## 附加伤害相对攻击飘字的延迟（秒），避免数字重叠。
const BONUS_DAMAGE_DELAY_SEC := 0.28

var relic_ui: RelicUI


func initialize_relic(owner: RelicUI) -> void:
	relic_ui = owner
	Events.player_dealt_attack_damage_to_enemy.connect(_on_player_dealt_attack_damage_to_enemy)


func deactivate_relic(_owner: RelicUI) -> void:
	if Events.player_dealt_attack_damage_to_enemy.is_connected(_on_player_dealt_attack_damage_to_enemy):
		Events.player_dealt_attack_damage_to_enemy.disconnect(_on_player_dealt_attack_damage_to_enemy)


func _on_player_dealt_attack_damage_to_enemy(_victim: Enemy, _amount: int) -> void:
	if Events.is_combat_ended() or not is_instance_valid(relic_ui):
		return
	var tree := relic_ui.get_tree()
	if tree == null:
		return
	var alive := EnemyTargeting.list_alive_enemies_sorted(tree)
	if alive.is_empty():
		return
	var target: Enemy = RNG.array_pick_random(alive) as Enemy
	if target == null:
		return
	_deal_bonus_damage_after_delay(target)


func _deal_bonus_damage_after_delay(target: Enemy) -> void:
	if not is_instance_valid(relic_ui):
		return
	var tree := relic_ui.get_tree()
	if tree == null:
		return
	await tree.create_timer(BONUS_DAMAGE_DELAY_SEC).timeout
	if Events.is_combat_ended() or not is_instance_valid(relic_ui):
		return
	if not is_instance_valid(target) or not is_instance_valid(target.stats):
		return
	if target.stats.health <= 0:
		return
	DamageEffect.create_fixed(bonus_damage).execute([target])
	relic_ui.flash()
