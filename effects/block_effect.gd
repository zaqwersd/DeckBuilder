class_name BlockEffect
extends Effect

const BLOCK_GAIN_SFX := preload("res://art/block.ogg")

var amount := 0
## 由玩家打出的卡牌触发的格挡（叠加敏捷）；遗物/敌人意图等为 false。
var from_card_play: bool = false


static func play_block_gain_sfx(_target: Node) -> void:
	SFXPlayer.play(BLOCK_GAIN_SFX)


static func compute_card_block_amount(base: int, combat_player: Node = null) -> int:
	var block := base
	if combat_player is Player:
		block = combat_player.modifier_handler.get_modified_value(block, Modifier.Type.BLOCK_GAINED)
	return block + DexterityStatus.get_bonus_from_player(combat_player)


func execute(targets: Array[Node]) -> void:
	for target in targets:
		if not target:
			continue
		if target is Enemy or target is Player:
			var total := amount
			if from_card_play and target is Player:
				total = compute_card_block_amount(amount, target)
			if total <= 0:
				continue
			target.stats.block += total
			play_block_gain_sfx(target)
