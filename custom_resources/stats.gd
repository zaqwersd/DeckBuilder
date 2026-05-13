class_name Stats
extends Resource

signal stats_changed
## 实际扣血（已扣除格挡后）且大于 0 时发出，用于飘字等
signal unblocked_damage_taken(amount: int)
## 实际回复的生命值（本次 heal 增加量）大于 0 时发出
signal healing_applied(amount: int)

@export_group("Battle UI")
## 血条（HealthRow 内）水平宽度（像素）。在角色 CharacterStats / 敌人 EnemyStats 的 .tres 中按立绘调整。
@export_range(40, 400, 1) var health_bar_width: int = 180
## StatusBar（血条+状态）相对「精灵脚底、水平居中」锚点的偏移；X 正向右，Y 正向下（与脚底间距）。
@export var status_bar_offset: Vector2 = Vector2(0, 14)
## 意图条相对 `enemy.tscn` 默认 IntentUI 边距的偏移：X 正向右；Y 正向上（会整体平移 offset_top / offset_bottom，并与 offset_left / offset_right 联动）。
@export var intent_ui_offset: Vector2 = Vector2.ZERO

@export var max_health := 1 : set = set_max_health
@export var art: Texture

var health: int : set = set_health
var block: int : set = set_block


func set_health(value : int) -> void:
	health = clampi(value, 0, max_health)
	stats_changed.emit()


func set_max_health(value : int) -> void:
	var diff := value - max_health
	max_health = value
	
	if diff > 0:
		health += diff
	elif health > max_health:
		health = max_health
	
	stats_changed.emit()


func set_block(value : int) -> void:
	block = clampi(value, 0, 999)
	stats_changed.emit()


func take_damage(damage : int) -> void:
	if damage <= 0:
		return
	var initial_damage = damage
	damage = clampi(damage - block, 0, damage)
	block = clampi(block - initial_damage, 0, block)
	health -= damage
	if damage > 0:
		unblocked_damage_taken.emit(damage)
	stats_changed.emit()


func heal(amount : int) -> void:
	if amount <= 0:
		return
	var before := health
	health += amount
	var gained := health - before
	if gained > 0:
		healing_applied.emit(gained)
	stats_changed.emit()


func create_instance() -> Resource:
	var instance: Stats = self.duplicate()
	instance.health = max_health
	instance.block = 0
	return instance
