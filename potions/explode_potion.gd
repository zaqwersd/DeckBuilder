extends Potion

@export var damage := 20


func perform_use(targets: Array[Node]) -> void:
	if targets.is_empty():
		return
	DamageEffect.create_fixed(damage).execute(targets)
