extends Relic

@export var damage := 3


func activate_relic(owner: RelicUI) -> void:
	var enemies := owner.get_tree().get_nodes_in_group("enemies")
	DamageEffect.create_fixed(damage).execute(enemies)
	owner.flash()
