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
