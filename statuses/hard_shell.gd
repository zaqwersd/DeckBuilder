class_name HardShellStatus
extends Status

signal shell_spent(host: Enemy)

const SPENT_ICON_MODULATE := Color(0.55, 0.55, 0.55, 1.0)

## 每回合阻挡第 m 次生命值减少。
@export var block_index: int = 1

var hits_this_turn: int = 0
var shell_active: bool = true


func get_tooltip() -> String:
	var text := (
		"抵挡每回合受到的前%s次生命值损伤。"
		% format_counter_for_tooltip(block_index)
	)
	if not shell_active:
		text += "（本回合已结束）"
	return text


## 玩家回合开始、所有回合开始效果之前：恢复硬壳。
func restore_for_player_turn() -> void:
	shell_active = true
	hits_this_turn = 0
	status_changed.emit()


## 玩家回合结束、敌人开始行动前：硬壳自动结束。
func expire_for_enemy_turn() -> void:
	if not shell_active:
		return
	shell_active = false
	status_changed.emit()


## 返回允许失去的生命值；0 表示本次硬壳完全阻挡。
func try_allow_hp_loss(hp_loss: int, host: Enemy) -> int:
	if hp_loss <= 0:
		return 0
	if not shell_active:
		return hp_loss
	var next_hit := hits_this_turn + 1
	if next_hit < block_index:
		hits_this_turn += 1
		return hp_loss
	if next_hit == block_index:
		hits_this_turn += 1
		_spend_shell(host)
		return 0
	return hp_loss


## 将本次伤害请求限制为：硬壳生效时第 m 次实际扣血归零（格挡仍正常消耗）。
func clamp_incoming_damage(requested: int, current_block: int, host: Enemy) -> int:
	var hp_damage := maxi(0, requested - current_block)
	if hp_damage <= 0:
		return requested
	var allowed_hp := try_allow_hp_loss(hp_damage, host)
	if allowed_hp == hp_damage:
		return requested
	if allowed_hp <= 0:
		return mini(requested, current_block)
	return current_block + allowed_hp


func _spend_shell(host: Enemy) -> void:
	if not shell_active:
		return
	shell_active = false
	status_changed.emit()
	if is_instance_valid(host):
		shell_spent.emit(host)


static func get_on_enemy(enemy: Enemy) -> HardShellStatus:
	if enemy == null or enemy.status_handler == null:
		return null
	return enemy.status_handler.get_status_by_id("hard_shell") as HardShellStatus


static func restore_all_in_tree(tree: SceneTree) -> void:
	if tree == null:
		return
	for node in tree.get_nodes_in_group("enemies"):
		if not node is Enemy:
			continue
		var hard_shell := get_on_enemy(node as Enemy)
		if hard_shell != null:
			hard_shell.restore_for_player_turn()


static func expire_all_in_tree(tree: SceneTree) -> void:
	if tree == null:
		return
	for node in tree.get_nodes_in_group("enemies"):
		if not node is Enemy:
			continue
		var hard_shell := get_on_enemy(node as Enemy)
		if hard_shell != null:
			hard_shell.expire_for_enemy_turn()
