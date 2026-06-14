class_name ShellMechEnemyStats
extends EnemyStats


func setup_battle_visual(enemy: Node) -> void:
	ShellMechEnemyVisual.attach_to(enemy)
