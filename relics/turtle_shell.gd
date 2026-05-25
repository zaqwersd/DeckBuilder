extends Relic

const BLOCK_SFX := preload("res://art/block.ogg")

@export var block_bonus := 4


func activate_relic(owner: RelicUI) -> void:
	var player := owner.get_tree().get_nodes_in_group("player")
	var block_effect := BlockEffect.new()
	block_effect.amount = block_bonus
	block_effect.sound = BLOCK_SFX
	block_effect.execute(player)
	
	owner.flash()
