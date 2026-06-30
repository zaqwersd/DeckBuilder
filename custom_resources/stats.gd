@tool
class_name Stats
extends Resource

signal stats_changed
## 实际扣血（已扣除格挡后）且大于 0 时发出，用于飘字等
signal unblocked_damage_taken(amount: int)
## 实际回复的生命值（本次 heal 增加量）大于 0 时发出
signal healing_applied(amount: int)

@export_group("Battle UI")
## 血条宽度（像素）。`uses_scene_ui_layout = true` 的敌人请改 `*_enemy.tscn` → StatusBar.container_width，此字段无效。
@export var health_bar_width: int = 180 : set = set_health_bar_width
## 已废弃：请改 `EnemyStats.enemy_scene` 内 StatusBar 位置。仅 `uses_scene_ui_layout = false` 时生效。
@export var status_bar_offset: Vector2 = Vector2(0, 14) : set = set_status_bar_offset
## 已废弃：请改 `EnemyStats.enemy_scene` 内 IntentUI 边距。仅 `uses_scene_ui_layout = false` 时生效。
@export var intent_ui_offset: Vector2 = Vector2.ZERO : set = set_intent_ui_offset

@export var max_health := 1 : set = set_max_health
@export var art: Texture : set = set_art

var health: int : set = set_health
var block: int : set = set_block
## take_damage 内部改血时避免 set_health 重复发出 unblocked_damage_taken
var _suppress_unblocked_damage_signal := false
## 可选：`(hp_loss: int) -> int`，在任意路径扣血前限制实际失去的生命值（如硬壳）。
var filter_unblocked_hp_loss: Callable


func set_health_bar_width(value: int) -> void:
	var clamped := HealthBar.normalize_bar_width(value)
	if health_bar_width == clamped:
		return
	health_bar_width = clamped
	if self is EnemyStats and (self as EnemyStats).uses_scene_ui_layout:
		return
	notify_battle_ui_preview_changed()


## 已废弃：场景布局敌人不再写回 .tres。
func apply_health_bar_width_from_scene(_value: int) -> void:
	pass


func set_status_bar_offset(value: Vector2) -> void:
	if status_bar_offset.is_equal_approx(value):
		return
	status_bar_offset = value
	notify_battle_ui_preview_changed()


func set_intent_ui_offset(value: Vector2) -> void:
	if intent_ui_offset.is_equal_approx(value):
		return
	intent_ui_offset = value
	notify_battle_ui_preview_changed()


func set_art(value: Texture) -> void:
	if art == value:
		return
	art = value
	notify_battle_ui_preview_changed()


## 编辑器中调整 Battle UI 数值时刷新 .tres 预览与战斗布局场景。
func notify_battle_ui_preview_changed() -> void:
	if not Engine.is_editor_hint():
		return
	emit_changed()
	_refresh_editor_battle_layout_previews(self)


static func _refresh_editor_battle_layout_previews(changed_stats: Stats) -> void:
	if changed_stats == null:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or not node.has_method("refresh_editor_battle_preview"):
			continue
		var enemy_stats: Variant = node.get("stats")
		if _editor_stats_matches(enemy_stats, changed_stats):
			Enemy.request_editor_battle_preview(node)


static func _editor_stats_matches(enemy_stats: Variant, changed_stats: Stats) -> bool:
	if enemy_stats == null or changed_stats == null:
		return false
	if enemy_stats == changed_stats:
		return true
	if enemy_stats is Resource and changed_stats is Resource:
		var path_a := (enemy_stats as Resource).resource_path
		var path_b := changed_stats.resource_path
		return path_a != "" and path_a == path_b
	return false


func set_health(value : int) -> void:
	var prev := health
	var clamped := clampi(value, 0, max_health)
	var loss := maxi(0, prev - clamped)
	if loss > 0 and filter_unblocked_hp_loss.is_valid():
		loss = maxi(0, int(filter_unblocked_hp_loss.call(loss)))
		clamped = prev - loss
	health = clamped
	if not _suppress_unblocked_damage_signal:
		var lost := maxi(0, prev - health)
		if lost > 0:
			unblocked_damage_taken.emit(lost)
	stats_changed.emit()


## 开战/召唤等初始化血量：不触发受伤飘字。
func initialize_health(max_hp: int, current_hp: int = -1) -> void:
	if current_hp < 0:
		current_hp = max_hp
	_suppress_unblocked_damage_signal = true
	max_health = max_hp
	health = current_hp
	_suppress_unblocked_damage_signal = false


func set_max_health(value : int) -> void:
	var diff := value - max_health
	max_health = value
	
	if diff > 0:
		health += diff
	elif health > max_health:
		health = max_health
	
	stats_changed.emit()
	notify_battle_ui_preview_changed()


func set_block(value : int) -> void:
	block = clampi(value, 0, 999)
	stats_changed.emit()


func take_damage(damage : int) -> void:
	if damage <= 0:
		return
	var initial_damage = damage
	damage = clampi(damage - block, 0, damage)
	block = clampi(block - initial_damage, 0, block)
	if damage > 0 and filter_unblocked_hp_loss.is_valid():
		damage = maxi(0, int(filter_unblocked_hp_loss.call(damage)))
	_suppress_unblocked_damage_signal = true
	health -= damage
	_suppress_unblocked_damage_signal = false
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


## 编辑器中 ExtResource 常为 placeholder（脚本未挂载），不可读 health/block 或调用脚本方法。
static func is_editor_placeholder(res: Resource) -> bool:
	if res == null or not Engine.is_editor_hint():
		return false
	if res.get_script() == null:
		return true
	if not res is Stats:
		return false
	# placeholder 仍可能暴露导出的 max_health，但读不到脚本里的 health/block。
	if res.get(&"health") == null:
		return true
	return false


static func is_editor_ui_usable(res: Stats) -> bool:
	if res == null:
		return false
	if not Engine.is_editor_hint():
		return true
	if is_editor_placeholder(res):
		return false
	var max_hp: Variant = res.get(&"max_health")
	if max_hp == null or int(max_hp) <= 0:
		return false
	return res.get(&"block") != null
