class_name EnemyAction
extends Node

enum Type {CONDITIONAL, CHANCE_BASED}

@export var intent: Intent
@export var sound: AudioStream
@export var type: Type
@export_range(0.0, 10.0) var chance_weight := 0.0

@onready var accumulated_weight := 0.0

## 普攻前冲：相对当前位置水平向左位移（像素），不冲到玩家身上
const ATTACK_HORIZONTAL_LUNGE_PX := 88.0

var enemy: Enemy
var target: Node2D


static func attack_lunge_position(start: Vector2) -> Vector2:
	return start + Vector2.LEFT * ATTACK_HORIZONTAL_LUNGE_PX


func is_performable() -> bool:
	return false


func perform_action() -> void:
	pass


func get_planned_intents() -> Array[Intent]:
	if intent == null:
		return []
	return [intent]


func update_planned_intents() -> void:
	update_intent_text()


func update_intent_text() -> void:
	if intent == null:
		return
	intent.current_text = intent.base_text
	intent.display_number = Intent.NUMBER_HIDDEN


## 与攻击意图一致：先玩家受伤修饰（易伤等），再敌人造成伤害修饰（力量等）。
func compute_damage_against_player(base_damage: int) -> int:
	var player := target as Player
	if not player or not enemy:
		return base_damage
	if player.status_handler:
		player.status_handler.sync_combat_modifiers_with_statuses()
	var after_player := player.modifier_handler.get_modified_value(
		base_damage, Modifier.Type.DMG_TAKEN
	)
	return enemy.modifier_handler.get_modified_value(after_player, Modifier.Type.DMG_DEALT)


## 已含完整修饰链的最终伤害；避免 DamageEffect 再次套用 DMG_TAKEN。
func make_final_player_damage_effect(final_damage: int) -> DamageEffect:
	var effect := DamageEffect.new()
	effect.amount = final_damage
	effect.receiver_modifier_type = Modifier.Type.NO_MODIFIER
	effect.sound = sound
	effect.dealt_by_enemy = enemy
	return effect
