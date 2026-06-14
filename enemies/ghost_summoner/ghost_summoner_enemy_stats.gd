class_name GhostSummonerEnemyStats
extends EnemyStats


func setup_battle_visual(enemy: Node) -> void:
	GhostSummonerEnemyVisual.attach_to(enemy)
