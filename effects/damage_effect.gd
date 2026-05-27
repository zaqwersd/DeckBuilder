class_name DamageEffect
extends Effect

var amount := 0
var receiver_modifier_type := Modifier.Type.DMG_TAKEN
var dealt_by_enemy: Enemy


## 固定数值伤害：不经攻击方 DMG_DEALT，目标侧也不修饰（遗物、药水等）。
static func create_fixed(amount: int) -> DamageEffect:
	var effect := DamageEffect.new()
	effect.amount = amount
	effect.receiver_modifier_type = Modifier.Type.NO_MODIFIER
	return effect


func execute(targets: Array[Node]) -> void:
	for target in targets:
		if not target:
			continue
		if target is Player and is_instance_valid(dealt_by_enemy):
			(target as Player).set_pending_damage_dealer(dealt_by_enemy)
		if target is Enemy or target is Player:
			if target is Player and receiver_modifier_type == Modifier.Type.NO_MODIFIER:
				(target as Player).take_damage_final(amount)
			else:
				target.take_damage(amount, receiver_modifier_type)
			SFXPlayer.play(sound)
