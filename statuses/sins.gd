class_name SinsStatus
extends Status

const DRAWS_PER_PROFANE := 10
const PROFANE := preload("res://common_cards/profane.tres")

## 罪孽尚未挂上时（如开局抽牌早于敌人 @onready）暂存的已抽张数。
static var _pending_draws: int = 0

## 距下次塞入亵渎还需抽几张牌（下标显示）。
var draws_until_profane: int = DRAWS_PER_PROFANE


static func reset_combat() -> void:
	_pending_draws = 0


static func prepare_fresh_on_enemy(sins: SinsStatus) -> void:
	if sins == null:
		return
	sins.draws_until_profane = DRAWS_PER_PROFANE


func get_tooltip() -> String:
	return tooltip


func record_player_draw(player: Player) -> Array[Card]:
	return record_player_draws(player, 1)


func record_player_draws(player: Player, count: int) -> Array[Card]:
	var inserted: Array[Card] = []
	if player == null or not is_instance_valid(player.stats) or count <= 0:
		return inserted
	for _i in range(count):
		draws_until_profane -= 1
		if draws_until_profane > 0:
			continue
		draws_until_profane = DRAWS_PER_PROFANE
		var profane := PROFANE.duplicate() as Card
		player.stats.draw_pile.insert_card_at_random(profane)
		inserted.append(profane)
	status_changed.emit()
	return inserted


static func notify_player_drew_cards(player: Player, count: int = 1) -> Array[Card]:
	var inserted: Array[Card] = []
	if player == null or Events.is_combat_ended() or count <= 0:
		return inserted
	var tree := player.get_tree()
	if tree == null:
		return inserted
	var enemy_handler := tree.get_first_node_in_group("enemy_handler") as EnemyHandler
	if enemy_handler == null:
		return inserted
	var applied := false
	for child in enemy_handler.get_children():
		if not child is Enemy:
			continue
		var enemy := child as Enemy
		if not is_instance_valid(enemy.stats) or enemy.stats.health <= 0:
			continue
		var sins := get_on_enemy(enemy)
		if sins != null:
			inserted.append_array(sins.record_player_draws(player, count))
			applied = true
	if not applied:
		_pending_draws += count
	return inserted


static func _on_player_drew_cards(player: Player, count: int, defer_side_animations: bool) -> void:
	var inserted := notify_player_drew_cards(player, count)
	for card: Card in inserted:
		if card == null:
			continue
		Events.draw_pile_insert_animation_requested.emit(card, defer_side_animations)


## 罪孽挂上后，补算挂载前已从抽牌堆抽出的张数。
static func consume_pending_draws(sins: SinsStatus, player: Player) -> Array[Card]:
	if sins == null or player == null or _pending_draws <= 0:
		return []
	var n := _pending_draws
	_pending_draws = 0
	return sins.record_player_draws(player, n)


static func play_insert_animations_for_cards(cards: Array[Card], player: Player) -> void:
	if player == null or cards.is_empty():
		return
	var tree := player.get_tree()
	if tree == null:
		return
	var ph := tree.get_first_node_in_group("player_handler") as PlayerHandler
	if ph == null:
		return
	await ph.play_draw_pile_insert_animations(cards)


static func get_on_enemy(host: Enemy) -> SinsStatus:
	if host == null or host.status_handler == null:
		return null
	return host.status_handler.get_status_by_id("sins") as SinsStatus
