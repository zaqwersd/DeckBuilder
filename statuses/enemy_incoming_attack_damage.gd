class_name EnemyIncomingAttackDamage
extends RefCounted

## 敌人有易伤时的承伤倍率（50% 增伤）。
const VULNERABLE_DAMAGE_MULT := 1.5


## 玩家攻击敌人：虚弱、易伤（含杀气）、挡箭鬼均为独立乘区，最后统一取整。
static func compute(base_damage: int, enemy: Enemy, player: Player) -> int:
	if base_damage <= 0 or enemy == null:
		return maxi(0, base_damage)
	var mult := (
		get_weak_multiplier(player)
		* get_vulnerable_multiplier(player, enemy)
		* get_scapeghost_multiplier(enemy)
	)
	return maxi(0, floori(float(base_damage) * mult))


static func get_weak_multiplier(player: Player) -> float:
	if player != null and WeakStatus.is_active_on(player):
		return WeakStatus.ATTACK_DAMAGE_MULTIPLIER
	return 1.0


## 易伤区：无易伤 1.0；有易伤 1.5；有杀气时 1.5 + 层数×(m/100)。
static func get_vulnerable_multiplier(player: Player, enemy: Node) -> float:
	return MaliceStatus.get_attack_damage_multiplier(player, enemy)


## 挡箭鬼区：场上有存活幽灵时 0.5，否则 1.0。
static func get_scapeghost_multiplier(enemy: Enemy) -> float:
	return ScapeghostStatus.get_damage_taken_multiplier(enemy)
