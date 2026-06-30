extends Potion

@export var block_amount := 12


func perform_use(targets: Array[Node]) -> void:
	if targets.is_empty():
		return
	var block_effect := BlockEffect.new()
	block_effect.amount = block_amount
	block_effect.execute(targets)
