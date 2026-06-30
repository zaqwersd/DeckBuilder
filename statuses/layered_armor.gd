class_name LayeredArmorStatus
extends Status

var _host: Enemy


func get_tooltip() -> String:
	return (
		"每个玩家回合开始时获得%s层格挡。每当受到未被格挡的攻击伤害，减少1层。"
		% format_counter_for_tooltip(stacks)
	)


func initialize_status(target: Node) -> void:
	if not target is Enemy:
		return
	_host = target as Enemy


func apply_status(_target: Node) -> void:
	status_applied.emit(self)


## 玩家回合开始：持有者按当前层数获得格挡（非施加层数时立即获得）。
static func grant_block_all_in_tree(tree: SceneTree) -> void:
	if tree == null:
		return
	for node in tree.get_nodes_in_group("enemies"):
		if not node is Enemy:
			continue
		var enemy := node as Enemy
		if not is_instance_valid(enemy.stats) or enemy.stats.health <= 0:
			continue
		var layered := get_on_enemy(enemy)
		if layered == null or layered.stacks <= 0:
			continue
		var block_effect := BlockEffect.new()
		block_effect.amount = layered.stacks
		block_effect.execute([enemy])


static func on_unblocked_attack_damage(enemy: Enemy, amount: int) -> void:
	if amount <= 0:
		return
	var layered := get_on_enemy(enemy)
	if layered == null or layered.stacks <= 0:
		return
	layered.set_stacks(layered.stacks - 1)
	if layered.stacks <= 0 and enemy.status_handler != null:
		enemy.status_handler.remove_status_by_id("layered_armor")


static func add_stacks_to(target: Enemy, amount: int) -> void:
	if amount <= 0 or target == null or target.status_handler == null:
		return
	var existing := get_on_enemy(target)
	if existing != null:
		existing.set_stacks(existing.stacks + amount)
		return
	var template: LayeredArmorStatus = load("res://statuses/layered_armor.tres") as LayeredArmorStatus
	if template == null:
		push_error("LayeredArmorStatus: 无法加载状态模板。")
		return
	var layered := template.duplicate() as LayeredArmorStatus
	if layered == null:
		push_error("LayeredArmorStatus: 无法复制状态模板。")
		return
	layered.set_stacks(amount)
	var effect := StatusEffect.new()
	effect.status = layered
	effect.execute([target])


static func get_on_enemy(enemy: Enemy) -> LayeredArmorStatus:
	if enemy == null or enemy.status_handler == null:
		return null
	var st := enemy.status_handler.get_status_by_id("layered_armor")
	if st == null:
		return null
	return st as LayeredArmorStatus
