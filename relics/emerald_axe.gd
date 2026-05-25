extends Relic

const STRENGTH_STATUS := preload("res://statuses/strength.tres")

@export var strength_gain := 1


func activate_relic(owner: RelicUI) -> void:
	var players := owner.get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var status_effect := StatusEffect.new()
	var muscle := STRENGTH_STATUS.duplicate(true)
	if muscle:
		muscle.stacks = strength_gain
	status_effect.status = muscle
	status_effect.execute(players)
	owner.flash()
