extends Relic

const DEXTERITY_STATUS := preload("res://statuses/dexterity.tres")

@export var dexterity_gain := 1


func activate_relic(owner: RelicUI) -> void:
	var players := owner.get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var status_effect := StatusEffect.new()
	var dex := DEXTERITY_STATUS.duplicate(true)
	if dex:
		dex.stacks = dexterity_gain
	status_effect.status = dex
	status_effect.execute(players)
	owner.flash()
