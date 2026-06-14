class_name MaliceStatus
extends Status

const EXPOSED_BASE_PERCENT := 0.5

## 累计百分比：每打出一张杀气累加卡面 m。
var m: int = 10


func get_tooltip() -> String:
	return tooltip % format_counter_for_tooltip(m)


static func get_on_player(player: Player) -> MaliceStatus:
	if player == null or player.status_handler == null:
		return null
	return player.status_handler.get_status_by_id("malice_state") as MaliceStatus


static func get_accumulated_m(player: Player) -> int:
	var st := get_on_player(player)
	return st.m if st else 0


static func get_exposed_layers_on(enemy: Node) -> int:
	if enemy == null or not enemy.get("status_handler"):
		return 0
	var st: Status = enemy.status_handler.get_status_by_id("exposed")
	if st == null or st.duration <= 0 or st.awaits_turn_start:
		return 0
	return st.duration


## 玩家有杀气且敌人有易伤时返回合并增伤（0.5 + m×层数/100）；否则 -1。
static func get_combined_vulnerable_percent(player: Player, enemy: Node) -> float:
	if get_on_player(player) == null:
		return -1.0
	var layers := get_exposed_layers_on(enemy)
	if layers <= 0:
		return -1.0
	return EXPOSED_BASE_PERCENT + float(get_accumulated_m(player) * layers) / 100.0


static func apply_to_attack_damage(player: Player, enemy: Node, damage_after_player_mods: int) -> int:
	var combined := get_combined_vulnerable_percent(player, enemy)
	if combined < 0.0:
		return damage_after_player_mods
	return maxi(0, ceili(float(damage_after_player_mods) * (1.0 + combined)))


static func resolve_enemy_from_modifier_handler(handler: ModifierHandler) -> Enemy:
	if handler == null or not is_instance_valid(handler):
		return null
	var node: Node = handler
	while node != null:
		if node is Enemy:
			return node as Enemy
		node = node.get_parent()
	return null


static func apply_to_attack_card_preview_damage(
	player: Node,
	damage_preview: int,
	card_type: Card.Type,
	enemy_modifiers: ModifierHandler
) -> int:
	if card_type != Card.Type.ATTACK or player == null or not (player is Player):
		return damage_preview
	var enemy := resolve_enemy_from_modifier_handler(enemy_modifiers)
	if enemy == null:
		return damage_preview
	return apply_to_attack_damage(player as Player, enemy, damage_preview)
