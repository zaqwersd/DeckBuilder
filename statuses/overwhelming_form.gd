class_name OverwhelmingStatus
extends Status


func get_tooltip() -> String:
	var s := stacks
	var mult := 1 + s
	return "攻击牌耗能增加%s；攻击牌伤害变为%s倍。" % [
		Status.format_tooltip_integer(s),
		Status.format_tooltip_integer(mult),
	]


static func stacks_on_player(player: Player) -> int:
	if player == null or player.status_handler == null:
		return 0
	var s := player.status_handler.get_status_by_id("overwhelming")
	return s.stacks if s else 0


## 易伤、力量等已在 `damage_after_vulnerable` 中结算完毕后再乘 (1+层数)。
static func apply_multiplier_to_final_attack_damage(player: Player, damage_after_vulnerable: int) -> int:
	var st := stacks_on_player(player)
	if st <= 0:
		return damage_after_vulnerable
	var mult := 1 + st
	return maxi(0, ceili(float(damage_after_vulnerable) * float(mult)))


## 卡面预览：仅攻击牌且玩家在战斗上下文时，把已含力量/易伤等的伤害再乘巨剑。
static func apply_to_attack_card_preview_damage(
	player: Node,
	damage_preview: int,
	card_type: Card.Type
) -> int:
	if card_type != Card.Type.ATTACK or player == null or not (player is Player):
		return damage_preview
	return apply_multiplier_to_final_attack_damage(player as Player, damage_preview)
