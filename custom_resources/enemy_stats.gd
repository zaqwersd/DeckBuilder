class_name EnemyStats
extends Stats

@export var ai: PackedScene
## 战斗贴图显示缩放（`enemy.tscn` 默认 3）；按敌人立绘在 .tres 中调整。
@export var art_scale := Vector2(3, 3)
## 多帧时在战斗中循环播放；少于 2 帧则仅用 `art`。
@export var art_frames: Array[Texture] = []
@export_range(0.05, 5.0, 0.05) var art_frame_interval: float = 0.5


func setup_battle_visual(_enemy: Enemy) -> void:
	pass
