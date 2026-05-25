class_name BlockEffect
extends Effect

var amount := 0
## 由玩家打出的卡牌触发的格挡（叠加敏捷）；遗物/敌人意图等为 false。
var from_card_play: bool = false


static func compute_card_block_amount(base: int, combat_player: Node = null) -> int:
	if combat_player == null:
		return base
	return base + DexterityStatus.get_bonus_from_player(combat_player)


func execute(targets: Array[Node]) -> void:
	for target in targets:
		if not target:
			continue
		if target is Enemy or target is Player:
			var total := amount
			if from_card_play and target is Player:
				total += DexterityStatus.get_bonus_from_player(target)
			target.stats.block += total
			SFXPlayer.play(sound)
